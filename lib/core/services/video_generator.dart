import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Color;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../i18n/strings.dart';
import '../models/models.dart';
import 'overlay_renderer.dart';

enum _RunResult { success, failed, cancelled }

/// Trop d'images pour la durée de la récitation : [maxImages] tient encore.
class TooManyImagesException implements Exception {
  final int maxImages;
  const TooManyImagesException(this.maxImages);
}

/// Pipeline FFmpeg en arrière-plan (l'UI reste fluide).
///
/// Étape 0 — texte : PNG par verset rendus par le moteur Flutter (même
///   peintre que l'aperçu), enchaînés par un ffconcat aux timings FFprobe
///   ROGNÉS des silences de bord (mêmes bornes que la preview).
/// Passe 1 (si plusieurs fonds) : normalisation 1080×1920@30 de chaque fond
///   (vidéo ou image, durée des images répartie automatiquement) puis
///   concaténation dans l'ordre, fondu croisé optionnel (0,5 s ; 0,25 s si
///   uniquement des images). Sortie sans audio.
/// Passe 2 : fond bouclé/coupé à la durée exacte de la récitation,
///   incrustation du texte, fondu de fin, encodage H.264 + AAC. Sans fond
///   média, une couleur unie (source lavfi) sert d'arrière-plan.
///
/// Audio : seul le flux de la récitation est mappé, découpé par
/// inpoint/outpoint (silences de bord) — continuité entre versets sans
/// toucher au contenu récité.
class VideoGenerator {
  static const int minImageMs = 1800;

  final OverlayRenderer _overlayRenderer = OverlayRenderer();

  // ────────────── Fonctions pures (couvertes par les tests) ──────────────

  static double crossfadeSecFor(List<BackgroundClip> clips) =>
      clips.isNotEmpty && clips.every((c) => c.isImage) ? 0.25 : 0.5;

  /// Durée effective de chaque fond : vidéos = durée réelle ; images = part
  /// égale du temps restant de la récitation (minimum [minImageMs]).
  static List<int> effectiveClipDurationsMs(
      List<BackgroundClip> clips, int totalAudioMs) {
    final imageCount = clips.where((c) => c.isImage).length;
    if (imageCount == 0) return [for (final c in clips) c.durationMs];
    final videosSum = clips
        .where((c) => !c.isImage)
        .fold<int>(0, (s, c) => s + c.durationMs);
    final available = totalAudioMs - videosSum;
    final perImage = available ~/ imageCount;
    if (perImage < minImageMs) {
      throw TooManyImagesException(max(0, available ~/ minImageMs));
    }
    return [
      for (final c in clips) c.isImage ? perImage : c.durationMs,
    ];
  }

  /// Offsets (s, timeline de sortie) des transitions xfade successives.
  static List<double> xfadeOffsets(List<int> durationsMs, double fadeSec) {
    final offsets = <double>[];
    var cumul = 0.0;
    for (var k = 1; k < durationsMs.length; k++) {
      cumul += durationsMs[k - 1] / 1000.0;
      offsets.add(cumul - k * fadeSec);
    }
    return offsets;
  }

  /// Durée utile (s) de la séquence de fond assemblée en passe 1.
  static double sequenceDurationSec(
      List<int> durationsMs, TransitionMode transition,
      {double fadeSec = 0.5}) {
    final sum = durationsMs.fold<int>(0, (s, d) => s + d) / 1000.0;
    if (transition != TransitionMode.fade) return sum;
    return sum - (durationsMs.length - 1) * fadeSec;
  }

  static String _normChain(int input, String label) =>
      '[$input:v]scale=1080:1920:force_original_aspect_ratio=increase,'
      'crop=1080:1920,setsar=1,fps=30,format=yuv420p[$label]';

  /// Graphe de filtres de la passe 1 (n ≥ 2 fonds) → flux [seq].
  static String buildSequenceFilter(
      List<int> durationsMs, TransitionMode transition,
      {double fadeSec = 0.5}) {
    final n = durationsMs.length;
    assert(n >= 2);
    final parts = <String>[
      for (var i = 0; i < n; i++) _normChain(i, 'p$i'),
    ];
    if (transition == TransitionMode.fade) {
      final offsets = xfadeOffsets(durationsMs, fadeSec);
      var current = 'p0';
      for (var k = 1; k < n; k++) {
        final out = k == n - 1 ? 'seq' : 'x$k';
        parts.add('[$current][p$k]xfade=transition=fade'
            ':duration=${fadeSec.toStringAsFixed(3)}'
            ':offset=${offsets[k - 1].toStringAsFixed(3)}[$out]');
        current = out;
      }
    } else {
      final inputs = [for (var i = 0; i < n; i++) '[p$i]'].join();
      parts.add('${inputs}concat=n=$n:v=1:a=0[seq]');
    }
    return parts.join(';');
  }

  /// Liste ffconcat de l'audio : un fichier par verset, découpé par
  /// inpoint/outpoint (silences de bord rognés, mêmes bornes que la preview).
  static String buildAudioConcat(List<VerseAudio> audios) {
    final sb = StringBuffer('ffconcat version 1.0\n');
    for (final a in audios) {
      sb.writeln("file '${a.localPath}'");
      if (a.inMs > 0) {
        sb.writeln('inpoint ${(a.inMs / 1000).toStringAsFixed(3)}');
      }
      if (a.outMs < a.fileDurationMs) {
        sb.writeln('outpoint ${(a.outMs / 1000).toStringAsFixed(3)}');
      }
    }
    return sb.toString();
  }

  /// Graphe de filtres de la passe 2 : fond → overlay texte → fondu de fin.
  static String buildFinalFilter({
    required int totalMs,
    required FadeColor fadeColor,
  }) {
    final totalSec = totalMs / 1000.0;
    final fadeDur = totalSec >= 8.0 ? 0.9 : (totalSec >= 3.0 ? 0.5 : 0.0);
    final base = '[0:v]scale=1080:1920:force_original_aspect_ratio=increase,'
        'crop=1080:1920,setsar=1,fps=30[bg];'
        '[bg][2:v]overlay=0:0';
    if (fadeDur <= 0) return '$base[v]';
    final fadeStart = totalSec - fadeDur;
    return '$base[txt];[txt]fade=t=out:st=${fadeStart.toStringAsFixed(3)}'
        ':d=${fadeDur.toStringAsFixed(3)}:color=${fadeColor.ffmpegColor}[v]';
  }

  static String _colorHex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);

  // ─────────────────────────── Pipeline ───────────────────────────

  Future<void> generate({
    required String outputFileName,
    required List<BackgroundClip> clips,
    Color? solidColor,
    required List<Verse> verses,
    required List<VerseAudio> audios,
    required StyleSettings style,
    required FadeColor fadeColor,
    required TransitionMode transition,
    required ExportQuality quality,
    required double yFraction,
    required String signature,
    required S strings,
    required void Function(GenerationState) onState,
  }) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final totalMs = audios.fold<int>(0, (sum, a) => sum + a.durationMs);

    if (clips.isEmpty && solidColor == null) {
      onState(GenerationState(GenerationPhase.error,
          message: strings.errNeedBackground));
      return;
    }

    final List<int> effDurations;
    try {
      effDurations = effectiveClipDurationsMs(clips, totalMs);
    } on TooManyImagesException catch (e) {
      onState(GenerationState(GenerationPhase.error,
          message: strings.errTooManyImages(e.maxImages)));
      return;
    }

    final multi = clips.length > 1;
    const overlayShare = 0.06;
    final pass1Share = multi ? 0.30 : 0.0;
    final pass2Share = 1.0 - overlayShare - pass1Share;

    onState(GenerationState(GenerationPhase.rendering,
        message: strings.renderingTextStart));
    final track = await _overlayRenderer.renderTrack(
      verses: verses,
      audios: audios,
      style: style,
      yFraction: yFraction,
      signature: signature,
      outputDir: tmp.path,
      onProgress: (done, total) => onState(GenerationState(
        GenerationPhase.rendering,
        progress: overlayShare * done / total,
        message: strings.renderingText(done, total),
      )),
    );

    final listFile = File('${tmp.path}/audio_$stamp.txt');
    await listFile.writeAsString(buildAudioConcat(audios));

    final cleanup = <String>[
      ...track.framePaths,
      track.concatPath,
      listFile.path,
    ];

    try {
      // ───── Passe 1 : assemblage des fonds (si plusieurs) ─────
      List<String> bgInput;
      if (clips.isEmpty) {
        bgInput = [
          '-f', 'lavfi',
          '-i', 'color=c=0x${_colorHex(solidColor!)}:s=1080x1920:r=30',
        ];
      } else if (!multi) {
        final clip = clips.first;
        bgInput = clip.isImage
            ? ['-loop', '1', '-i', clip.path]
            : ['-stream_loop', '-1', '-i', clip.path];
      } else {
        final fadeSec = crossfadeSecFor(clips);
        final seqSec = sequenceDurationSec(effDurations, transition,
            fadeSec: fadeSec);
        final targetSec = min(seqSec, totalMs / 1000.0 + 0.5);
        final seqPath = '${tmp.path}/sequence_$stamp.mp4';
        cleanup.add(seqPath);
        List<String> pass1Args(String vcodec, List<String> opts) => [
              '-y',
              for (var i = 0; i < clips.length; i++) ...[
                if (clips[i].isImage) ...[
                  '-loop', '1',
                  '-t', (effDurations[i] / 1000).toStringAsFixed(3),
                ],
                '-i', clips[i].path,
              ],
              '-filter_complex',
              buildSequenceFilter(effDurations, transition, fadeSec: fadeSec),
              '-map', '[seq]', '-an',
              '-t', targetSec.toStringAsFixed(3),
              '-c:v', vcodec, ...opts,
              '-pix_fmt', 'yuv420p',
              seqPath,
            ];
        var r1 = await _run(
          pass1Args('libx264', ['-preset', 'veryfast', '-crf', '18']),
          (targetSec * 1000).round(),
          strings,
          (p, eta) => onState(GenerationState(
            GenerationPhase.rendering,
            progress: overlayShare + pass1Share * p,
            message: strings.assembling((p * 100).round(), eta),
          )),
        );
        if (r1 == _RunResult.failed) {
          r1 = await _run(pass1Args('mpeg4', ['-q:v', '3']),
              (targetSec * 1000).round(), strings, (p, eta) {});
        }
        if (r1 == _RunResult.cancelled) {
          onState(const GenerationState.idle());
          return;
        }
        if (r1 != _RunResult.success) {
          onState(GenerationState(GenerationPhase.error,
              message: strings.errAssemble));
          return;
        }
        bgInput = ['-stream_loop', '-1', '-i', seqPath];
      }

      // ───── Passe 2 : rendu final ─────
      final outPath = '${tmp.path}/$outputFileName';
      final filter = buildFinalFilter(totalMs: totalMs, fadeColor: fadeColor);
      List<String> pass2Args(String vcodec, List<String> opts) => [
            '-y',
            ...bgInput,
            '-f', 'concat', '-safe', '0', '-i', listFile.path,
            '-f', 'concat', '-safe', '0', '-i', track.concatPath,
            '-filter_complex', filter,
            '-map', '[v]', '-map', '1:a',
            '-t', (totalMs / 1000).toStringAsFixed(3),
            '-c:v', vcodec, ...opts,
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-b:a', '192k',
            '-movflags', '+faststart',
            outPath,
          ];
      final baseProgress = overlayShare + pass1Share;
      void reportPass2(double p, String eta) => onState(GenerationState(
            GenerationPhase.rendering,
            progress: baseProgress + pass2Share * p,
            message: strings.encoding((p * 100).round(), eta),
          ));
      var result = await _run(
        pass2Args('libx264',
            ['-preset', 'veryfast', '-crf', quality.crf.toString()]),
        totalMs,
        strings,
        reportPass2,
      );
      if (result == _RunResult.failed) {
        result = await _run(
            pass2Args('mpeg4', ['-q:v', '4']), totalMs, strings, reportPass2);
      }
      if (result == _RunResult.cancelled) {
        onState(const GenerationState.idle());
        return;
      }
      if (result != _RunResult.success) {
        onState(GenerationState(GenerationPhase.error,
            message: strings.errEncode));
        return;
      }

      onState(GenerationState(GenerationPhase.saving,
          progress: 1, message: strings.savingGallery));
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(outPath, album: 'NUQTA');

      onState(GenerationState(
        GenerationPhase.done,
        progress: 1,
        message: strings.savedAs(outputFileName),
        outputPath: outPath,
      ));
    } finally {
      for (final path in cleanup) {
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // Nettoyage best-effort des fichiers temporaires.
        }
      }
    }
  }

  Future<_RunResult> _run(
    List<String> arguments,
    int targetMs,
    S strings,
    void Function(double progress, String eta) onProgress,
  ) {
    final completer = Completer<_RunResult>();
    final started = DateTime.now();
    FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isCancel(rc)) {
          completer.complete(_RunResult.cancelled);
        } else if (ReturnCode.isSuccess(rc)) {
          completer.complete(_RunResult.success);
        } else {
          completer.complete(_RunResult.failed);
        }
      },
      null,
      (statistics) {
        if (targetMs <= 0) return;
        final p =
            (statistics.getTime().toDouble() / targetMs).clamp(0.0, 1.0);
        var eta = '';
        final elapsed = DateTime.now().difference(started).inSeconds;
        if (p > 0.05 && elapsed >= 2) {
          eta = strings.etaSuffix((elapsed * (1 - p) / p).round());
        }
        onProgress(p, eta);
      },
    );
    return completer.future;
  }

  void cancel() {
    FFmpegKit.cancel();
  }
}
