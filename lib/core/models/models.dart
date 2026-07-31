import 'dart:ui';

/// Une sourate telle que décrite par l'API quran.com (endpoint /chapters).
class Chapter {
  final int id;
  final String nameSimple;
  final String nameArabic;
  final String translatedName;
  final int versesCount;

  const Chapter({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
    required this.translatedName,
    required this.versesCount,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'] as int,
        nameSimple: json['name_simple'] as String? ?? '',
        nameArabic: json['name_arabic'] as String? ?? '',
        translatedName:
            ((json['translated_name'] as Map<String, dynamic>?)?['name']
                    as String?) ??
                '',
        versesCount: json['verses_count'] as int,
      );
}

/// Un récitateur du catalogue statique vérifié (reciter_catalog.dart).
/// [everyayahFolder] : dossier sur everyayah.com (source primaire).
/// [fallbackEdition]/[fallbackBitrate] : édition cdn.islamic.network (secours).
class Reciter {
  final String id;
  final String name;
  final String style;
  final String everyayahFolder;
  final String? fallbackEdition;
  final int fallbackBitrate;

  const Reciter({
    required this.id,
    required this.name,
    this.style = '',
    required this.everyayahFolder,
    this.fallbackEdition,
    this.fallbackBitrate = 128,
  });

  String get displayName => style.isEmpty ? name : '$name ($style)';
}

/// Un verset : texte uthmani + traduction (éventuellement vide).
class Verse {
  final String verseKey; // ex : "1:1"
  final int number; // numéro du verset dans la sourate
  final String arabic;
  final String translation;

  const Verse({
    required this.verseKey,
    required this.number,
    required this.arabic,
    required this.translation,
  });
}

/// Un audio de verset téléchargé localement, avec sa durée mesurée par FFprobe.
class VerseAudio {
  final String verseKey;
  final String localPath;
  final int durationMs;

  const VerseAudio({
    required this.verseKey,
    required this.localPath,
    required this.durationMs,
  });
}

/// Langue de traduction — resourceId = identifiant de la ressource quran.com.
enum TranslationLang {
  none(null, 'Aucune'),
  french(31, 'Français'), // Muhammad Hamidullah
  english(20, 'English'); // Saheeh International

  final int? resourceId;
  final String label;
  const TranslationLang(this.resourceId, this.label);
}

/// Police arabe : famille Flutter (pubspec) et nom de famille interne du .ttf
/// (utilisé par libass dans le fichier ASS).
enum ArabicFont {
  amiri('Amiri', 'Amiri', 'Amiri'),
  scheherazade('Scheherazade', 'ScheherazadeNew', 'Scheherazade New');

  final String label;
  final String flutterFamily;
  final String assFamily;
  const ArabicFont(this.label, this.flutterFamily, this.assFamily);
}

/// Réglages de style appliqués à l'incrustation (aperçu et rendu final).
class StyleSettings {
  final Color textColor;
  final double boxOpacity; // opacité du fond derrière le texte, 0..0.9
  final TranslationLang translation;
  final ArabicFont font;
  final double sizeScale; // 0.7..1.4

  const StyleSettings({
    this.textColor = const Color(0xFFFFFFFF),
    this.boxOpacity = 0.35,
    this.translation = TranslationLang.french,
    this.font = ArabicFont.amiri,
    this.sizeScale = 1.0,
  });

  StyleSettings copyWith({
    Color? textColor,
    double? boxOpacity,
    TranslationLang? translation,
    ArabicFont? font,
    double? sizeScale,
  }) =>
      StyleSettings(
        textColor: textColor ?? this.textColor,
        boxOpacity: boxOpacity ?? this.boxOpacity,
        translation: translation ?? this.translation,
        font: font ?? this.font,
        sizeScale: sizeScale ?? this.sizeScale,
      );
}

/// Couleur du fondu appliqué sur les derniers instants de la vidéo finale.
enum FadeColor {
  black('Noir', 'black'),
  white('Blanc', 'white');

  final String label;
  final String ffmpegColor;
  const FadeColor(this.label, this.ffmpegColor);
}

/// Phase du pipeline de génération FFmpeg.
enum GenerationPhase { idle, rendering, saving, done, error }

class GenerationState {
  final GenerationPhase phase;
  final double progress; // 0..1, pertinent en phase rendering
  final String message;
  final String? outputPath;

  const GenerationState(
    this.phase, {
    this.progress = 0,
    this.message = '',
    this.outputPath,
  });

  const GenerationState.idle() : this(GenerationPhase.idle);

  bool get isBusy =>
      phase == GenerationPhase.rendering || phase == GenerationPhase.saving;
}
