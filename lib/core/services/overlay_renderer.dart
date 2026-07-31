import 'dart:io';
import 'dart:ui' as ui;

import '../models/models.dart';
import '../render/overlay_painter.dart';

/// Piste de texte prête pour FFmpeg : un PNG plein cadre (1080×1920, fond
/// transparent) par verset + un fichier ffconcat qui les enchaîne aux timings
/// exacts mesurés par FFprobe.
class OverlayTrack {
  final String concatPath;
  final List<String> framePaths;

  const OverlayTrack({required this.concatPath, required this.framePaths});
}

/// Rasterise les versets avec le MÊME peintre que l'aperçu
/// (OverlayFramePainter) : l'export reproduit l'aperçu au pixel près.
class OverlayRenderer {
  /// Construit le contenu du fichier ffconcat (démuxeur concat de FFmpeg).
  /// Le dernier PNG est répété sans durée : le démuxeur ignore parfois la
  /// durée de la dernière entrée, et le filtre overlay répète de toute façon
  /// la dernière frame jusqu'à la fin (eof_action=repeat par défaut).
  static String buildConcat(List<String> files, List<int> durationsMs) {
    assert(files.length == durationsMs.length && files.isNotEmpty);
    final sb = StringBuffer('ffconcat version 1.0\n');
    for (var i = 0; i < files.length; i++) {
      sb.writeln("file '${files[i]}'");
      sb.writeln(
          'duration ${(durationsMs[i] / 1000).toStringAsFixed(3)}');
    }
    sb.writeln("file '${files.last}'");
    return sb.toString();
  }

  Future<OverlayTrack> renderTrack({
    required List<Verse> verses,
    required List<VerseAudio> audios,
    required StyleSettings style,
    required double yFraction,
    required String outputDir,
    required void Function(int done, int total) onProgress,
  }) async {
    assert(verses.length == audios.length);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final files = <String>[];
    for (var i = 0; i < verses.length; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        const ui.Rect.fromLTWH(
            0, 0, OverlayFramePainter.frameW, OverlayFramePainter.frameH),
      );
      OverlayFramePainter.paint(
        canvas,
        verse: verses[i],
        style: style,
        yFraction: yFraction,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        OverlayFramePainter.frameW.toInt(),
        OverlayFramePainter.frameH.toInt(),
      );
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        throw Exception('rasterisation du verset ${verses[i].verseKey}');
      }
      final path = '$outputDir/overlay_${stamp}_$i.png';
      await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      files.add(path);
      onProgress(i + 1, verses.length);
    }
    final concatPath = '$outputDir/overlay_$stamp.ffconcat';
    await File(concatPath).writeAsString(
      buildConcat(files, [for (final a in audios) a.durationMs]),
    );
    return OverlayTrack(concatPath: concatPath, framePaths: files);
  }
}
