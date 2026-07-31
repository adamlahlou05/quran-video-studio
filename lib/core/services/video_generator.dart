import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'overlay_renderer.dart';

enum _RunResult { success, failed, cancelled }

/// Pipeline FFmpeg en arrière-plan (l'UI reste fluide).
///
/// Étape 0 — texte : chaque verset est rasterisé en PNG par le moteur Flutter
///   (même peintre que l'aperçu → export fidèle au pixel près), enchaînés par
///   un fichier ffconcat aux timings FFprobe.
/// Passe 1 (uniquement si plusieurs vidéos de fond) : normalisation
///   1080×1920@30 de chaque clip puis concaténation dans l'ordre choisi,
///   avec fondu croisé optionnel de 0,5 s (xfade). Sortie sans audio.
/// Passe 2 : fond bouclé (-stream_loop -1) et coupé à la durée exacte de la
///   récitation (-t), incrustation de la piste texte (overlay), fondu de fin
///   noir/blanc, encodage H.264 (CRF selon la qualité choisie) + AAC.
///
/// Audio : seul le flux de la récitation concaténée est mappé — les pistes
/// audio des vidéos importées n'entrent jamais dans le fichier final.
class VideoGenerator {
  static const double crossfadeSec = 0.5;

  final OverlayRenderer _overlayRenderer = OverlayRenderer();

  // ────────────────── Fonctions pures (couvertes par les tests) ──────────────────

  /// Offsets (secondes, timeline de sortie) des transitions xfade successives.
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
      List<int> durationsMs, TransitionMode transition) {
    final sum = durationsMs.fold<int>(0, (s, d) => s + d) / 1000.0;
    if (transition != TransitionMode.fade) return sum;
    return sum - (durationsMs.length - 1) * crossfadeSec;
  }

  static String _normChain(int input, String label) =>
      '[$input:v]scale=1080:1920:force_original_aspect_ratio=increase,'
      'crop=1080:1920,setsar=1,fps=30,format=yuv420p[$label]';

  /// Graphe de filtres de la passe 1 (n ≥ 2 clips) → flux [seq].
  static String buildSequenceFilter(
      List<int> durationsMs, TransitionMode transition) {
    final n = durationsMs.length;
    assert(n >= 2);
    final parts = <String>[
      for (var i = 0; i < n; i++) _normChain(i, 'p$i'),
    ];
    if (transition == TransitionMode.fade) {
      final offsets = xfadeOffsets(durationsMs, crossfadeSec);
      var current = 'p0';
      for (var k = 1; k < n; k++) {
        final out = k == n - 1 ? 'seq' : 'x$k';
        parts.add('[$current][p$k]xfade=transition=fade'
            ':duration=${crossfadeSec.toStringAsFixed(3)}'
            ':offset=${offsets[k - 1].toStringAsFixed(3)}[$out]');
        current = out;
      }
    } else {
      final inputs = [for (var i = 0; i < n; i++) '[p$i]'].join();
      parts.add('${inputs}concat=n=$n:v=1:a=0[seq]');
    }
    return parts.join(';');
  }

  /// Graphe de filtres de la passe 2 : fond → overlay texte → fondu de fin.
  /// Entrées : 0 = fond vidéo, 1 = audio récitation, 2 = piste PNG du texte.
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

  // ─────────────────────────── Pipeline ───────────────────────────

  Future<void> generate({
    required String outputFileName,
    required List<BackgroundClip> clips,
    required List<Verse> verses,
    required List<VerseAudio> audios,
    required StyleSettings style,
    required FadeColor fadeColor,
    required TransitionMode transition,
    required ExportQuality quality,
    required double yFraction,
    required String signature,
    required void Function(GenerationState) onState,
  }) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final totalMs = audios.fold<int>(0, (sum, a) => sum + a.durationMs);
    final multi = clips.length > 1;

    // Pondération de la progression globale par phase.
    const overlayShare = 0.06;
    final pass1Share = multi ? 0.30 : 0.0;
    final pass2Share = 1.0 - overlayShare - pass1Share;

    onState(const GenerationState(
      GenerationPhase.rendering,
      message: 'Rendu du texte…',
    ));
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
        message: 'Rendu du texte : $done/$total',
      )),
    );

    final listFile = File('${tmp.path}/audio_$stamp.txt');
    await listFile
        .writeAsString(audios.map((a) => "file '${a.localPath}'").join('\n'));

    final cleanup = <String>[...track.framePaths, track.concatPath,
        listFile.path];

    try {
      // ───── Passe 1 : assemblage des fonds (si plusieurs vidéos) ─────
      String backgroundPath = clips.first.path;
      if (multi) {
        final durations = [for (final c in clips) c.durationMs];
        final seqSec = sequenceDurationSec(durations, transition);
        final targetSec = min(seqSec, totalMs / 1000.0 + 0.5);
        final seqPath = '${tmp.path}/sequence_$stamp.mp4';
        cleanup.add(seqPath);
        List<String> pass1Args(String vcodec, List<String> opts) => [
              '-y',
              for (final c in clips) ...['-i', c.path],
              '-filter_complex', buildSequenceFilter(durations, transition),
              '-map', '[seq]', '-an',
              '-t', targetSec.toStringAsFixed(3),
              '-c:v', vcodec, ...opts,
              '-pix_fmt', 'yuv420p',
              seqPath,
            ];
        var r1 = await _run(
          pass1Args('libx264', ['-preset', 'veryfast', '-crf', '18']),
          (targetSec * 1000).round(),
          (p, eta) => onState(GenerationState(
            GenerationPhase.rendering,
            progress: overlayShare + pass1Share * p,
            message: 'Assemblage des vidéos : ${(p * 100).round()} %$eta',
          )),
        );
        if (r1 == _RunResult.failed) {
          r1 = await _run(pass1Args('mpeg4', ['-q:v', '3']),
              (targetSec * 1000).round(), (p, eta) {});
        }
        if (r1 == _RunResult.cancelled) {
          onState(const GenerationState.idle());
          return;
        }
        if (r1 != _RunResult.success) {
          onState(const GenerationState(
            GenerationPhase.error,
            message: "Impossible d'assembler les vidéos de fond. "
                'Réessaie avec des fichiers mp4.',
          ));
          return;
        }
        backgroundPath = seqPath;
      }

      // ───── Passe 2 : rendu final ─────
      // Le nom du fichier est conservé par Gal/MediaStore : c'est lui que
      // l'utilisateur voit dans la galerie, Google Photos et le partage.
      final outPath = '${tmp.path}/$outputFileName';
      final filter = buildFinalFilter(totalMs: totalMs, fadeColor: fadeColor);
      List<String> pass2Args(String vcodec, List<String> opts) => [
            '-y',
            '-stream_loop', '-1', '-i', backgroundPath,
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
      var result = await _run(
        pass2Args('libx264',
            ['-preset', 'veryfast', '-crf', quality.crf.toString()]),
        totalMs,
        (p, eta) => onState(GenerationState(
          GenerationPhase.rendering,
          progress: baseProgress + pass2Share * p,
          message: 'Encodage vidéo : ${(p * 100).round()} %$eta',
        )),
      );
      if (result == _RunResult.failed) {
        result = await _run(pass2Args('mpeg4', ['-q:v', '4']), totalMs,
            (p, eta) => onState(GenerationState(
                  GenerationPhase.rendering,
                  progress: baseProgress + pass2Share * p,
                  message: 'Encodage vidéo : ${(p * 100).round()} %$eta',
                )));
      }
      if (result == _RunResult.cancelled) {
        onState(const GenerationState.idle());
        return;
      }
      if (result != _RunResult.success) {
        onState(const GenerationState(
          GenerationPhase.error,
          message: "FFmpeg n'a pas pu encoder la vidéo. "
              'Réessaie avec une autre vidéo de fond (mp4 recommandé).',
        ));
        return;
      }

      onState(const GenerationState(
        GenerationPhase.saving,
        progress: 1,
        message: 'Enregistrement dans la galerie…',
      ));
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(outPath, album: 'NUQTA');

      onState(GenerationState(
        GenerationPhase.done,
        progress: 1,
        message: 'Enregistrée : $outputFileName',
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

  /// Exécute FFmpeg ; [onProgress] reçoit la fraction 0..1 et une estimation
  /// du temps restant (chaîne vide tant qu'elle n'est pas fiable).
  Future<_RunResult> _run(
    List<String> arguments,
    int targetMs,
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
          final remaining = (elapsed * (1 - p) / p).round();
          eta = ' — ~$remaining s restantes';
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
