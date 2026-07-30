import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'subtitle_builder.dart';

enum _RunResult { success, failed, cancelled }

/// Pipeline FFmpeg exécuté en arrière-plan (l'UI reste fluide) :
///  1. concaténation des mp3 par verset (demuxer concat) ;
///  2. fond vidéo bouclé (-stream_loop -1), recadré en 1080×1920 ;
///  3. incrustation du texte via le filtre subtitles (libass + fontsdir) ;
///  4. encodage H.264 + AAC, repli MPEG-4 si libx264 est absent de la build ;
///  5. enregistrement du .mp4 dans la galerie (album "Quran Video Studio").
class VideoGenerator {
  Future<void> generate({
    required String backgroundPath,
    required List<Verse> verses,
    required List<VerseAudio> audios,
    required StyleSettings style,
    required double yFraction,
    required String fontsDir,
    required void Function(GenerationState) onState,
  }) async {
    onState(const GenerationState(
      GenerationPhase.rendering,
      message: 'Préparation des fichiers…',
    ));

    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final totalMs = audios.fold<int>(0, (sum, a) => sum + a.durationMs);

    final listFile = File('${tmp.path}/audio_$stamp.txt');
    await listFile
        .writeAsString(audios.map((a) => "file '${a.localPath}'").join('\n'));

    final subsFile = File('${tmp.path}/subs_$stamp.ass');
    await subsFile.writeAsString(SubtitleBuilder.buildAss(
      verses: verses,
      audios: audios,
      style: style,
      yFraction: yFraction,
    ));

    final outPath = '${tmp.path}/quran_video_$stamp.mp4';
    final filter = '[0:v]scale=1080:1920:force_original_aspect_ratio=increase,'
        'crop=1080:1920,setsar=1,fps=30,'
        "subtitles=filename='${subsFile.path}':fontsdir='$fontsDir'[v]";

    List<String> buildArgs(String vcodec, List<String> vcodecOpts) => [
          '-y',
          '-stream_loop', '-1', '-i', backgroundPath,
          '-f', 'concat', '-safe', '0', '-i', listFile.path,
          '-filter_complex', filter,
          '-map', '[v]', '-map', '1:a',
          '-t', (totalMs / 1000).toStringAsFixed(3),
          '-c:v', vcodec, ...vcodecOpts,
          '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-b:a', '192k',
          '-movflags', '+faststart',
          outPath,
        ];

    var result = await _run(
      buildArgs('libx264', ['-preset', 'veryfast', '-crf', '23']),
      totalMs,
      onState,
    );
    if (result == _RunResult.failed) {
      result = await _run(buildArgs('mpeg4', ['-q:v', '4']), totalMs, onState);
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
    await Gal.putVideo(outPath, album: 'Quran Video Studio');

    onState(GenerationState(
      GenerationPhase.done,
      progress: 1,
      message: 'Vidéo enregistrée dans la galerie.',
      outputPath: outPath,
    ));
  }

  Future<_RunResult> _run(
    List<String> arguments,
    int totalMs,
    void Function(GenerationState) onState,
  ) {
    final completer = Completer<_RunResult>();
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
        if (totalMs <= 0) return;
        final progress =
            (statistics.getTime().toDouble() / totalMs).clamp(0.0, 1.0);
        onState(GenerationState(
          GenerationPhase.rendering,
          progress: progress,
          message: 'Encodage vidéo : ${(progress * 100).toStringAsFixed(0)} %',
        ));
      },
    );
    return completer.future;
  }

  void cancel() {
    FFmpegKit.cancel();
  }
}
