import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/models.dart';

/// Peintre UNIQUE du bloc de texte incrusté, en résolution native 1080×1920.
///
/// C'est la garantie « ce que je vois est ce que j'exporte » : l'aperçu
/// dessine cette frame mise à l'échelle du canvas, et l'export rasterise la
/// même frame en PNG incrusté par FFmpeg. Même moteur texte Flutter partout →
/// taille, position, couleur, police, boîte et retours à la ligne identiques
/// par construction. (L'ancien pipeline libass interprétait la taille de
/// police comme une hauteur de cellule — d'où un texte 2 à 3× trop petit avec
/// les polices arabes aux métriques verticales géantes.)
class OverlayFramePainter {
  static const double frameW = 1080;
  static const double frameH = 1920;

  /// Largeur maximale du texte (marges latérales de 72 px de chaque côté).
  static const double contentWidth = frameW - 2 * 72;

  static const double arabicBaseSize = 68;
  static const double transBaseSize = 34;
  static const double padH = 32;
  static const double padV = 22;
  static const double gap = 12;
  static const double radius = 24;

  /// Peint la frame complète (fond transparent) sur [canvas], dans le repère
  /// 1080×1920. Renvoie le rectangle du bloc dessiné (repère 1080×1920),
  /// utilisé par l'aperçu pour le drag & drop.
  static Rect paint(
    ui.Canvas canvas, {
    required Verse? verse,
    required StyleSettings style,
    required double yFraction,
  }) {
    if (verse == null) {
      return _paintHint(canvas, yFraction);
    }
    final hasBox = style.boxOpacity > 0.01;
    final shadows = hasBox
        ? null
        : const [Shadow(blurRadius: 6, color: Colors.black87)];

    final arabic = TextPainter(
      text: TextSpan(
        text: verse.arabic,
        style: TextStyle(
          fontFamily: style.font.flutterFamily,
          fontSize: arabicBaseSize * style.sizeScale,
          height: 1.8,
          color: style.textColor,
          shadows: shadows,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: contentWidth);

    TextPainter? trans;
    if (style.translation != TranslationLang.none &&
        verse.translation.isNotEmpty) {
      trans = TextPainter(
        text: TextSpan(
          text: verse.translation,
          style: TextStyle(
            fontFamily: style.font.flutterFamily,
            fontSize: transBaseSize * style.sizeScale,
            height: 1.35,
            color: style.textColor.withValues(alpha: 0.95),
            shadows: shadows,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: contentWidth);
    }

    final textW = max(arabic.width, trans?.width ?? 0);
    final blockW = min(contentWidth, textW) + 2 * padH;
    final blockH =
        arabic.height + (trans == null ? 0 : gap + trans.height) + 2 * padV;
    final cy = (yFraction * frameH)
        .clamp(blockH / 2 + 16, frameH - blockH / 2 - 16)
        .toDouble();
    final rect = Rect.fromCenter(
      center: Offset(frameW / 2, cy),
      width: blockW,
      height: blockH,
    );

    if (hasBox) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
        Paint()..color = Colors.black.withValues(alpha: style.boxOpacity),
      );
    }
    arabic.paint(
      canvas,
      Offset(frameW / 2 - arabic.width / 2, rect.top + padV),
    );
    trans?.paint(
      canvas,
      Offset(
        frameW / 2 - trans.width / 2,
        rect.top + padV + arabic.height + gap,
      ),
    );
    return rect;
  }

  /// Message d'aide affiché tant qu'aucun verset n'est chargé (aperçu
  /// uniquement : l'export exige des versets).
  static Rect _paintHint(ui.Canvas canvas, double yFraction) {
    final hint = TextPainter(
      text: const TextSpan(
        text: 'Choisis une sourate et des versets…',
        style: TextStyle(color: Colors.white70, fontSize: 34),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: contentWidth);
    final cy = (yFraction * frameH).clamp(60.0, frameH - 60.0).toDouble();
    final rect = Rect.fromCenter(
      center: Offset(frameW / 2, cy),
      width: hint.width + 2 * padH,
      height: hint.height + 2 * padV,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    hint.paint(
        canvas, Offset(frameW / 2 - hint.width / 2, rect.top + padV));
    return rect;
  }
}
