import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../render/overlay_painter.dart';

/// Fonds dégradés proposés pour les images-citations.
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

/// Image-citation fixe 1080×1920 : fond dégradé + verset rendu par le MÊME
/// peintre que l'aperçu et la vidéo (style, position, police et signature
/// identiques à ce que l'utilisateur a réglé).
class ImageQuoteRenderer {
  static Future<Uint8List> render({
    required Verse verse,
    required StyleSettings style,
    required double yFraction,
    required QuoteBackground background,
    String signature = '',
  }) async {
    const rect = ui.Rect.fromLTWH(
        0, 0, OverlayFramePainter.frameW, OverlayFramePainter.frameH);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.top, background.bottom],
        ).createShader(rect),
    );
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
}
