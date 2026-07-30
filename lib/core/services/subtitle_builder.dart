import 'dart:ui';

import '../models/models.dart';

/// Génère le fichier de sous-titres ASS incrusté par libass.
///
/// Pourquoi ASS plutôt que drawtext : libass est compilé avec fribidi et
/// harfbuzz, donc l'arabe est correctement façonné (ligatures, harakat,
/// direction droite-à-gauche), là où drawtext afficherait des lettres
/// déconnectées. Le timing de chaque verset découle des durées mesurées par
/// FFprobe : le texte apparaît exactement quand le récitateur le prononce.
class SubtitleBuilder {
  /// Résolution de rendu du script : identique à la sortie vidéo.
  static const int playResX = 1080;
  static const int playResY = 1920;

  /// Tailles de base (en pixels ASS, pour PlayRes 1080×1920), modulées par
  /// StyleSettings.sizeScale. Les mêmes valeurs servent à l'aperçu Flutter,
  /// ce qui garantit un aperçu fidèle au rendu final.
  static const double arabicBaseSize = 68;
  static const double transBaseSize = 34;

  static String buildAss({
    required List<Verse> verses,
    required List<VerseAudio> audios,
    required StyleSettings style,
    required double yFraction,
  }) {
    assert(verses.length == audios.length);
    final arabicSize = (arabicBaseSize * style.sizeScale).round();
    final transSize = (transBaseSize * style.sizeScale).round();
    final posY = (yFraction * playResY).round();
    final primary = _assColor(style.textColor);
    final hasBox = style.boxOpacity > 0.01;
    // Alpha ASS : 00 = opaque, FF = transparent.
    final backAlpha = (255 * (1 - style.boxOpacity)).round().clamp(0, 255);
    final back = '&H${_hex(backAlpha)}000000';
    final borderStyle = hasBox ? 3 : 1; // 3 = boîte opaque, 1 = contour
    final outline = hasBox ? 10 : 3;
    final shadow = hasBox ? 0 : 1;
    final font = style.font.assFamily;

    final sb = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('PlayResX: $playResX')
      ..writeln('PlayResY: $playResY')
      ..writeln('WrapStyle: 0')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln(
          'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, '
          'OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, '
          'ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, '
          'Alignment, MarginL, MarginR, MarginV, Encoding')
      ..writeln('Style: Arabic,$font,$arabicSize,$primary,&H000000FF,'
          '&H00000000,$back,0,0,0,0,100,100,0,0,$borderStyle,$outline,$shadow,'
          '5,64,64,0,1')
      ..writeln('Style: Trans,$font,$transSize,$primary,&H000000FF,'
          '&H00000000,$back,0,0,0,0,100,100,0,0,$borderStyle,$outline,$shadow,'
          '5,64,64,0,1')
      ..writeln()
      ..writeln('[Events]')
      ..writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, '
          'MarginV, Effect, Text');

    var t = 0;
    for (var i = 0; i < verses.length; i++) {
      final start = _timestamp(t);
      t += audios[i].durationMs;
      final end = _timestamp(t);
      final text = StringBuffer(
          '{\\an5\\pos(${playResX ~/ 2},$posY)}${_escape(verses[i].arabic)}');
      final translation = _escape(verses[i].translation);
      if (style.translation != TranslationLang.none && translation.isNotEmpty) {
        text.write('\\N{\\rTrans}$translation');
      }
      sb.writeln('Dialogue: 0,$start,$end,Arabic,,0,0,0,,$text');
    }
    return sb.toString();
  }

  /// Format ASS : H:MM:SS.CC (centisecondes).
  static String _timestamp(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    return '$h:${_pad(m)}:${_pad(s)}.${_pad(cs)}';
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');

  /// { } sont des balises de style ASS ; \N est le seul retour ligne valide.
  static String _escape(String s) => s
      .replaceAll('{', '(')
      .replaceAll('}', ')')
      .replaceAll(RegExp(r'\r?\n'), '\\N');

  /// Couleur ASS : &HAABBGGRR (ordre bleu-vert-rouge, alpha inversé).
  static String _assColor(Color color) {
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return '&H00${_hex(b)}${_hex(g)}${_hex(r)}';
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
}
