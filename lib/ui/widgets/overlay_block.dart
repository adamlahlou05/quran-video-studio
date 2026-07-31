import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/render/overlay_painter.dart';
import '../../providers/editor_controller.dart';

/// Aperçu du texte incrusté : dessine la frame 1080×1920 du
/// [OverlayFramePainter] mise à l'échelle du canvas. C'est le MÊME code que
/// celui qui rasterise les PNG de l'export — l'aperçu est donc fidèle au
/// rendu final par construction (taille, position, couleur, retours à la
/// ligne identiques).
class OverlayPreview extends ConsumerWidget {
  /// Rect du bloc dessiné, en coordonnées du canvas (pour le drag & drop).
  final ValueNotifier<Rect?> blockRect;

  const OverlayPreview({super.key, required this.blockRect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verses = ref.watch(editorProvider.select((s) => s.verses));
    final index = ref.watch(editorProvider.select((s) => s.previewIndex));
    final style = ref.watch(editorProvider.select((s) => s.style));
    final yFraction = ref.watch(editorProvider.select((s) => s.yFraction));
    final verse =
        verses.isEmpty ? null : verses[index.clamp(0, verses.length - 1)];

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OverlayPreviewPainter(verse, style, yFraction, blockRect),
      ),
    );
  }
}

class _OverlayPreviewPainter extends CustomPainter {
  final Verse? verse;
  final StyleSettings style;
  final double yFraction;
  final ValueNotifier<Rect?> blockRect;

  _OverlayPreviewPainter(this.verse, this.style, this.yFraction,
      this.blockRect);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / OverlayFramePainter.frameW;
    canvas.save();
    canvas.scale(scale);
    final rect = OverlayFramePainter.paint(
      canvas,
      verse: verse,
      style: style,
      yFraction: yFraction,
    );
    canvas.restore();
    blockRect.value = Rect.fromLTWH(
      rect.left * scale,
      rect.top * scale,
      rect.width * scale,
      rect.height * scale,
    );
  }

  @override
  bool shouldRepaint(_OverlayPreviewPainter oldDelegate) =>
      oldDelegate.verse != verse ||
      oldDelegate.style != style ||
      oldDelegate.yFraction != yFraction;
}
