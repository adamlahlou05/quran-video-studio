import '../core/models/models.dart';
import '../core/services/export_naming.dart';

/// État immuable de l'éditeur single-screen. Toute l'UI en dérive.
class EditorState {
  /// Vidéos d'arrière-plan, dans l'ordre de lecture choisi par l'utilisateur.
  final List<BackgroundClip> clips;
  final Chapter? chapter;
  final int ayahFrom;
  final int ayahTo;
  final Reciter? reciter;
  final StyleSettings style;

  /// Couleur du fondu de fin de la vidéo générée (noir ou blanc).
  final FadeColor fadeColor;

  /// Transition entre les vidéos de fond enchaînées (aucune / fondu 0,5 s).
  final TransitionMode transition;

  /// Qualité d'encodage de l'export.
  final ExportQuality quality;

  /// Hashtags ajoutés à la description de partage (modifiables, persistés).
  final String hashtags;

  /// Position verticale du bloc de texte : centre du bloc, en fraction de la
  /// hauteur de la frame (0 = haut, 1 = bas). Même valeur utilisée par le
  /// peintre partagé de l'aperçu et de l'export.
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
    this.clips = const [],
    this.chapter,
    this.ayahFrom = 1,
    this.ayahTo = 5,
    this.reciter,
    this.style = const StyleSettings(),
    this.fadeColor = FadeColor.black,
    this.transition = TransitionMode.none,
    this.quality = ExportQuality.standard,
    this.hashtags = kDefaultHashtags,
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
      clips.isNotEmpty && audioReady && !loadingVerses;

  int get clipsTotalMs => clips.fold<int>(0, (sum, c) => sum + c.durationMs);

  int get totalDurationMs => audios.fold<int>(0, (sum, a) => sum + a.durationMs);

  EditorState copyWith({
    List<BackgroundClip>? clips,
    Chapter? chapter,
    int? ayahFrom,
    int? ayahTo,
    Reciter? reciter,
    StyleSettings? style,
    FadeColor? fadeColor,
    TransitionMode? transition,
    ExportQuality? quality,
    String? hashtags,
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
        clips: clips ?? this.clips,
        chapter: chapter ?? this.chapter,
        ayahFrom: ayahFrom ?? this.ayahFrom,
        ayahTo: ayahTo ?? this.ayahTo,
        reciter: reciter ?? this.reciter,
        style: style ?? this.style,
        fadeColor: fadeColor ?? this.fadeColor,
        transition: transition ?? this.transition,
        quality: quality ?? this.quality,
        hashtags: hashtags ?? this.hashtags,
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
