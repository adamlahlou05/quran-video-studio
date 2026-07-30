import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/services/subtitle_builder.dart';
import '../../providers/editor_state.dart';

/// Bloc de texte incrusté sur l'aperçu. Les tailles sont dérivées des mêmes
/// constantes que le fichier ASS (échelle canvas/1080), pour que l'aperçu
/// corresponde au rendu FFmpeg final.
class OverlayBlock extends StatelessWidget {
  final EditorState state;
  final double canvasWidth;

  const OverlayBlock({
    super.key,
    required this.state,
    required this.canvasWidth,
  });

  @override
  Widget build(BuildContext context) {
    final scale = canvasWidth / SubtitleBuilder.playResX;
    final style = state.style;
    final hasBox = style.boxOpacity > 0.01;
    final verse = state.verses.isEmpty
        ? null
        : state.verses[state.previewIndex.clamp(0, state.verses.length - 1)];
    final shadows = hasBox
        ? null
        : const [Shadow(blurRadius: 6, color: Colors.black87)];

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 18 * scale + 6,
          vertical: 10 * scale + 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: style.boxOpacity),
          borderRadius: BorderRadius.circular(12),
        ),
        child: verse == null
            ? const Text(
                'Choisis une sourate et des versets…',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    verse.arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: style.font.flutterFamily,
                      fontSize: SubtitleBuilder.arabicBaseSize *
                          style.sizeScale *
                          scale,
                      height: 1.8,
                      color: style.textColor,
                      shadows: shadows,
                    ),
                  ),
                  if (style.translation != TranslationLang.none &&
                      verse.translation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        verse.translation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: style.font.flutterFamily,
                          fontSize: SubtitleBuilder.transBaseSize *
                              style.sizeScale *
                              scale,
                          height: 1.35,
                          color: style.textColor.withValues(alpha: 0.95),
                          shadows: shadows,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
