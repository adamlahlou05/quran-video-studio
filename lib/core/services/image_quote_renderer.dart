import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../render/overlay_painter.dart';

/// Fonds dégradés prédéfinis pour les images-citations.
enum QuoteBackground {
  night('Nuit', Color(0xFF15393B), Color(0xFF0B1D22)),
  black('Noir', Color(0xFF1A1A1A), Color(0xFF000000)),
  gold('Or sombre', Color(0xFF4A3A12), Color(0xFF140E02)),
  ivory('Ivoire', Color(0xFFF7F2E7), Color(0xFFDDD2BB));

  final String label;
  final Color top;
  final Color bottom;
  const QuoteBackground(this.label, this.top, this.bottom);
}

/// Fond d'une image-citation : dégradé prédéfini, couleur libre, ou image de
/// la galerie (recadrée en « cover » 1080×1920 sans déformation).
class QuoteBgSpec {
  final QuoteBackground? preset;
  final Color? color;
  final String? imagePath;

  const QuoteBgSpec.preset(QuoteBackground this.preset)
      : color = null,
        imagePath = null;
  const QuoteBgSpec.color(Color this.color)
      : preset = null,
        imagePath = null;
  const QuoteBgSpec.image(String this.imagePath)
      : preset = null,
        color = null;
}

/// Image-citation fixe 1080×1920 : fond + verset rendu par le MÊME peintre
/// que l'aperçu et la vidéo (style, position, police, signature identiques).
class ImageQuoteRenderer {
  static const _rect = ui.Rect.fromLTWH(
      0, 0, OverlayFramePainter.frameW, OverlayFramePainter.frameH);

  static Future<Uint8List> render({
    required Verse verse,
    required StyleSettings style,
    required double yFraction,
    required QuoteBgSpec background,
    String signature = '',
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, _rect);
    await _paintBackground(canvas, background);
    OverlayFramePainter.paint(
      canvas,
      verse: verse,
      style: style,
      yFraction: yFraction,
      signature: signature,
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
      throw Exception("rasterisation de l'image impossible");
    }
    return bytes.buffer.asUint8List();
  }

  static Future<void> _paintBackground(
      ui.Canvas canvas, QuoteBgSpec bg) async {
    if (bg.imagePath != null) {
      final image = await _decodeCover(bg.imagePath!);
      final srcRatio = image.width / image.height;
      const dstRatio =
          OverlayFramePainter.frameW / OverlayFramePainter.frameH;
      // Recadrage centré « cover » : aucune déformation.
      ui.Rect src;
      if (srcRatio > dstRatio) {
        final cropW = image.height * dstRatio;
        src = ui.Rect.fromLTWH(
            (image.width - cropW) / 2, 0, cropW, image.height.toDouble());
      } else {
        final cropH = image.width / dstRatio;
        src = ui.Rect.fromLTWH(
            0, (image.height - cropH) / 2, image.width.toDouble(), cropH);
      }
      canvas.drawImageRect(
          image, src, _rect, ui.Paint()..filterQuality = ui.FilterQuality.high);
      image.dispose();
      return;
    }
    final paint = ui.Paint();
    if (bg.color != null) {
      paint.color = bg.color!;
    } else {
      final preset = bg.preset ?? QuoteBackground.night;
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [preset.top, preset.bottom],
      ).createShader(_rect);
    }
    canvas.drawRect(_rect, paint);
  }

  /// Décode l'image à une taille bornée (assez pour couvrir 1080×1920, jamais
  /// la pleine résolution d'une photo 48 Mpx en mémoire).
  static Future<ui.Image> _decodeCover(String path) async {
    final bytes = await File(path).readAsBytes();
    // Sonde légère pour connaître le ratio (32 px de large).
    final probeCodec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
    final probe = (await probeCodec.getNextFrame()).image;
    final ratio = probe.width / probe.height;
    probe.dispose();
    probeCodec.dispose();
    final ui.Codec codec;
    if (ratio > OverlayFramePainter.frameW / OverlayFramePainter.frameH) {
      codec = await ui.instantiateImageCodec(bytes,
          targetHeight: OverlayFramePainter.frameH.toInt());
    } else {
      codec = await ui.instantiateImageCodec(bytes,
          targetWidth: OverlayFramePainter.frameW.toInt());
    }
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
