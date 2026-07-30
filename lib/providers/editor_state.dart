import '../core/models/models.dart';

/// État immuable de l'éditeur single-screen. Toute l'UI en dérive.
class EditorState {
  final String? backgroundPath;
  final Chapter? chapter;
  final int ayahFrom;
  final int ayahTo;
  final Reciter? reciter;
  final StyleSettings style;

  /// Position verticale du bloc de texte : centre du bloc, en fraction de la
  /// hauteur du canvas (0 = haut, 1 = bas). Même valeur envoyée à l'ASS.
  final double yFraction;

  final List<Verse> verses;
  final bool loadingVerses;
  final String? versesError;

  final List<VerseAudio> audios;
  final bool loadingAudio;
  final double audioProgress;
  final String? audioError;

  final int previewIndex;
  final bool isPlaying;

  final GenerationState generation;

  const EditorState({
    this.backgroundPath,
    this.chapter,
    this.ayahFrom = 1,
    this.ayahTo = 5,
    this.reciter,
    this.style = const StyleSettings(),
    this.yFraction = 0.5,
    this.verses = const [],
    this.loadingVerses = false,
    this.versesError,
    this.audios = const [],
    this.loadingAudio = false,
    this.audioProgress = 0,
    this.audioError,
    this.previewIndex = 0,
    this.isPlaying = false,
    this.generation = const GenerationState.idle(),
  });

  int get verseCount => ayahTo - ayahFrom + 1;

  bool get audioReady =>
      verses.isNotEmpty && !loadingAudio && audios.length == verses.length;

  bool get readyToGenerate =>
      backgroundPath != null && audioReady && !loadingVerses;

  int get totalDurationMs => audios.fold<int>(0, (sum, a) => sum + a.durationMs);

  EditorState copyWith({
    String? backgroundPath,
    Chapter? chapter,
    int? ayahFrom,
    int? ayahTo,
    Reciter? reciter,
    StyleSettings? style,
    double? yFraction,
    List<Verse>? verses,
    bool? loadingVerses,
    Object? versesError = _sentinel,
    List<VerseAudio>? audios,
    bool? loadingAudio,
    double? audioProgress,
    Object? audioError = _sentinel,
    int? previewIndex,
    bool? isPlaying,
    GenerationState? generation,
  }) =>
      EditorState(
        backgroundPath: backgroundPath ?? this.backgroundPath,
        chapter: chapter ?? this.chapter,
        ayahFrom: ayahFrom ?? this.ayahFrom,
        ayahTo: ayahTo ?? this.ayahTo,
        reciter: reciter ?? this.reciter,
        style: style ?? this.style,
        yFraction: yFraction ?? this.yFraction,
        verses: verses ?? this.verses,
        loadingVerses: loadingVerses ?? this.loadingVerses,
        versesError: versesError == _sentinel
            ? this.versesError
            : versesError as String?,
        audios: audios ?? this.audios,
        loadingAudio: loadingAudio ?? this.loadingAudio,
        audioProgress: audioProgress ?? this.audioProgress,
        audioError:
            audioError == _sentinel ? this.audioError : audioError as String?,
        previewIndex: previewIndex ?? this.previewIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        generation: generation ?? this.generation,
      );

  static const Object _sentinel = Object();
}
