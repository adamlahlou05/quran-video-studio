import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api/quran_api.dart';
import '../core/data/reciter_catalog.dart';
import '../core/models/models.dart';
import '../core/services/audio_service.dart';
import '../core/services/export_naming.dart';
import '../core/services/image_quote_renderer.dart';
import '../core/services/media_probe.dart';
import '../core/services/settings_service.dart';
import '../core/services/video_generator.dart';
import 'editor_state.dart';

final quranApiProvider = Provider<QuranApi>((ref) => QuranApi());
final audioServiceProvider = Provider<AudioService>((ref) => AudioService());

final chaptersProvider = FutureProvider<List<Chapter>>(
  (ref) => ref.watch(quranApiProvider).fetchChapters(),
);

/// Catalogue statique vérifié : disponible immédiatement, sans réseau.
final recitersProvider = Provider<List<Reciter>>((ref) => kReciters);

final editorProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);

/// Points d'accroche verticaux du bloc de texte : haut, milieu, bas.
const List<double> kSnapFractions = [0.18, 0.5, 0.82];

class EditorController extends Notifier<EditorState> {
  final AudioPlayer _player = AudioPlayer();
  final VideoGenerator _generator = VideoGenerator();
  final SettingsService _settings = SettingsService();

  Timer? _rangeDebounce;
  int _versesToken = 0;
  int _audioToken = 0;
  int _playToken = 0;

  final Map<String, List<Verse>> _verseCache = {};

  @override
  EditorState build() {
    ref.onDispose(() {
      _rangeDebounce?.cancel();
      _player.dispose();
    });
    // Sélections par défaut : le récitateur vient du catalogue statique
    // (Alafasy en tête) ; la sourate dès que l'API répond (Al-Fatiha).
    Future.microtask(() {
      if (state.reciter == null && kReciters.isNotEmpty) {
        setReciter(kReciters.first);
      }
    });
    Future.wait([
      _settings.loadHashtags(),
      _settings.loadSignature(),
      _settings.loadFavoriteReciters(),
    ]).then((values) {
      state = state.copyWith(
        hashtags: values[0] as String,
        signature: values[1] as String,
        favoriteReciters: values[2] as List<String>,
      );
    });
    ref.listen(chaptersProvider, (previous, next) {
      next.whenData((chapters) {
        Future.microtask(() {
          if (state.chapter == null && chapters.isNotEmpty) {
            selectChapter(chapters.first);
          }
        });
      });
    });
    return const EditorState();
  }

  // ──────────────────── Vidéos d'arrière-plan ────────────────────

  /// Ouvre le sélecteur système (multi-sélection) et ajoute les vidéos
  /// choisies à la séquence, dans l'ordre. Seul un sondage FFprobe est fait
  /// (lecture des en-têtes) : aucune copie ni conversion supplémentaire.
  /// Renvoie le nombre de fichiers rejetés (pas des vidéos lisibles).
  Future<int> pickAndAddClips() async {
    final picked = await ImagePicker().pickMultipleMedia();
    if (picked.isEmpty) return 0;
    var rejected = 0;
    final added = <BackgroundClip>[];
    for (final file in picked) {
      final duration = await MediaProbe.durationMs(file.path);
      if (duration == null) {
        rejected++;
      } else {
        added.add(BackgroundClip(path: file.path, durationMs: duration));
      }
    }
    if (added.isNotEmpty) {
      state = state.copyWith(clips: [...state.clips, ...added]);
    }
    return rejected;
  }

  void removeClip(int index) {
    if (index < 0 || index >= state.clips.length) return;
    final clips = [...state.clips]..removeAt(index);
    state = state.copyWith(clips: clips);
  }

  /// Déplace un clip d'une position (delta = -1 vers le haut, +1 vers le bas).
  void moveClip(int index, int delta) {
    final target = index + delta;
    if (index < 0 ||
        index >= state.clips.length ||
        target < 0 ||
        target >= state.clips.length) {
      return;
    }
    final clips = [...state.clips];
    final clip = clips.removeAt(index);
    clips.insert(target, clip);
    state = state.copyWith(clips: clips);
  }

  void setTransition(TransitionMode mode) {
    state = state.copyWith(transition: mode);
  }

  /// Ajout direct d'un clip déjà sondé (import par lien).
  void addClip(BackgroundClip clip) {
    state = state.copyWith(clips: [...state.clips, clip]);
  }

  void setHashtags(String value) {
    state = state.copyWith(hashtags: value);
    unawaited(_settings.saveHashtags(value));
  }

  void setSignature(String value) {
    state = state.copyWith(signature: value);
    unawaited(_settings.saveSignature(value));
  }

  void toggleFavoriteReciter(String reciterId) {
    final favorites = [...state.favoriteReciters];
    if (!favorites.remove(reciterId)) {
      favorites.add(reciterId);
    }
    state = state.copyWith(favoriteReciters: favorites);
    unawaited(_settings.saveFavoriteReciters(favorites));
  }

  /// Exporte une image-citation PNG du verset [verseIndex] (index dans la
  /// plage chargée) vers la galerie ; renvoie le nom du fichier créé.
  Future<String> exportQuoteImage({
    required int verseIndex,
    required QuoteBackground background,
  }) async {
    final s = state;
    final verse = s.verses[verseIndex];
    final bytes = await ImageQuoteRenderer.render(
      verse: verse,
      style: s.style,
      yFraction: s.yFraction,
      background: background,
      signature: s.signature,
    );
    final number = await _settings.nextImageNumber();
    final baseName = buildImageFileName(
      number: number,
      reciter: s.reciter!,
      chapter: s.chapter!,
      verseNumber: verse.number,
    );
    if (!await Gal.hasAccess(toAlbum: true)) {
      await Gal.requestAccess(toAlbum: true);
    }
    await Gal.putImageBytes(bytes, album: 'NUQTA', name: baseName);
    return '$baseName.png';
  }

  void setQuality(ExportQuality quality) {
    state = state.copyWith(quality: quality);
  }

  // ─────────────────────────── Contenu ───────────────────────────

  void selectChapter(Chapter chapter) {
    stopPreview();
    state = state.copyWith(
      chapter: chapter,
      ayahFrom: 1,
      ayahTo: chapter.versesCount < 5 ? chapter.versesCount : 5,
      verses: const [],
      audios: const [],
      previewIndex: 0,
      generation: const GenerationState.idle(),
      versesError: null,
      audioError: null,
    );
    _reloadVerses();
    _reloadAudio();
  }

  void setRange(int from, int to) {
    final chapter = state.chapter;
    if (chapter == null) return;
    final safeFrom = from.clamp(1, chapter.versesCount);
    final safeTo = to.clamp(safeFrom, chapter.versesCount);
    if (safeFrom == state.ayahFrom && safeTo == state.ayahTo) return;
    stopPreview();
    // loadingAudio/loadingVerses passent à true immédiatement pour bloquer la
    // génération pendant la fenêtre de debounce.
    state = state.copyWith(
      ayahFrom: safeFrom,
      ayahTo: safeTo,
      loadingVerses: true,
      loadingAudio: true,
      audios: const [],
      previewIndex: 0,
    );
    _rangeDebounce?.cancel();
    _rangeDebounce = Timer(const Duration(milliseconds: 500), () {
      _reloadVerses();
      _reloadAudio();
    });
  }

  void reloadVerses() => _reloadVerses();
  void reloadAudio() => _reloadAudio();

  // ─────────────────────────── Récitateur ───────────────────────────

  void setReciter(Reciter reciter) {
    if (state.reciter?.id == reciter.id) return;
    stopPreview();
    state = state.copyWith(
      reciter: reciter,
      audios: const [],
      audioError: null,
    );
    _reloadAudio();
  }

  // ─────────────────────────── Style ───────────────────────────

  void setTextColor(Color color) {
    state = state.copyWith(style: state.style.copyWith(textColor: color));
  }

  void setBoxOpacity(double opacity) {
    state = state.copyWith(style: state.style.copyWith(boxOpacity: opacity));
  }

  void setSizeScale(double scale) {
    state = state.copyWith(style: state.style.copyWith(sizeScale: scale));
  }

  void setFont(ArabicFont font) {
    state = state.copyWith(style: state.style.copyWith(font: font));
  }

  void setTranslation(TranslationLang lang) {
    if (lang == state.style.translation) return;
    state = state.copyWith(style: state.style.copyWith(translation: lang));
    _reloadVerses();
  }

  void setFadeColor(FadeColor color) {
    state = state.copyWith(fadeColor: color);
  }

  // ─────────────────────────── Position (drag & drop) ───────────────────────

  void setYFraction(double fraction) {
    state = state.copyWith(yFraction: fraction.clamp(0.08, 0.92));
  }

  /// Aimante la position sur Haut / Milieu / Bas si on en est proche.
  void snapY() {
    for (final snap in kSnapFractions) {
      if ((state.yFraction - snap).abs() < 0.07) {
        state = state.copyWith(yFraction: snap);
        return;
      }
    }
  }

  // ─────────────────────────── Chargements ───────────────────────────

  Future<void> _reloadVerses() async {
    final chapter = state.chapter;
    if (chapter == null) return;
    final lang = state.style.translation;
    final token = ++_versesToken;
    state = state.copyWith(loadingVerses: true, versesError: null);
    try {
      final cacheKey = '${chapter.id}|${lang.name}';
      var all = _verseCache[cacheKey];
      all ??= await ref.read(quranApiProvider).fetchVerses(
            chapterId: chapter.id,
            translationId: lang.resourceId,
          );
      _verseCache[cacheKey] = all;
      if (token != _versesToken) return;
      if (all.isEmpty) {
        throw Exception('aucun verset reçu');
      }
      // Bornes prudentes : l'API peut renvoyer moins de versets qu'annoncé.
      final upper = state.ayahTo.clamp(1, all.length);
      final lower = (state.ayahFrom - 1).clamp(0, upper - 1);
      final slice = all.sublist(lower, upper);
      state = state.copyWith(
        verses: slice,
        loadingVerses: false,
        previewIndex: 0,
      );
    } catch (e) {
      if (token != _versesToken) return;
      state = state.copyWith(
        loadingVerses: false,
        versesError: 'Versets indisponibles (connexion ?) — $e',
      );
    }
  }

  Future<void> _reloadAudio() async {
    final chapter = state.chapter;
    final reciter = state.reciter;
    if (chapter == null || reciter == null) return;
    stopPreview();
    final token = ++_audioToken;
    state = state.copyWith(
      loadingAudio: true,
      audioProgress: 0,
      audioError: null,
      audios: const [],
    );
    try {
      final service = ref.read(audioServiceProvider);
      final from = state.ayahFrom;
      final to = state.ayahTo;
      final count = to - from + 1;
      final result = <VerseAudio>[];
      for (var n = from; n <= to; n++) {
        final key = '${chapter.id}:$n';
        final audio = await service.fetchVerseAudio(
          reciterId: reciter.id,
          verseKey: key,
          urls: audioUrlCandidates(reciter, chapter.id, n),
        );
        if (token != _audioToken) return;
        result.add(audio);
        state = state.copyWith(audioProgress: result.length / count);
      }
      if (token != _audioToken) return;
      state = state.copyWith(
        audios: result,
        loadingAudio: false,
        audioProgress: 1,
      );
    } catch (e) {
      if (token != _audioToken) return;
      state = state.copyWith(
        loadingAudio: false,
        audioError: 'Audio de ${reciter.name} indisponible — vérifie ta '
            'connexion puis réessaie. Détail : $e',
      );
    }
  }

  // ─────────────────────────── Aperçu audio ───────────────────────────

  /// Joue les versets en séquence ; l'overlay suit le verset en cours, ce qui
  /// donne un aperçu fidèle de la synchronisation du rendu final.
  Future<void> togglePreview() async {
    if (state.isPlaying) {
      await stopPreview();
      return;
    }
    if (!state.audioReady) return;
    final audios = state.audios;
    final token = ++_playToken;
    state = state.copyWith(isPlaying: true, previewIndex: 0);
    try {
      for (var i = 0; i < audios.length; i++) {
        if (token != _playToken) return;
        state = state.copyWith(previewIndex: i);
        await _player.setFilePath(audios[i].localPath);
        if (token != _playToken) return;
        unawaited(_player.play());
        await _player.processingStateStream.firstWhere(
          (s) => s == ProcessingState.completed || s == ProcessingState.idle,
        );
        if (token != _playToken) return;
      }
    } catch (_) {
      // Lecture interrompue (changement de récitateur, stop…) : sans gravité.
    } finally {
      if (token == _playToken) {
        state = state.copyWith(isPlaying: false, previewIndex: 0);
        await _player.stop();
      }
    }
  }

  Future<void> stopPreview() async {
    _playToken++;
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false, previewIndex: 0);
    }
    await _player.stop();
  }

  // ─────────────────────────── Génération ───────────────────────────

  Future<void> generate() async {
    final s = state;
    if (s.generation.isBusy) return;
    if (s.clips.isEmpty) {
      _setGenerationError("Importe d'abord au moins une vidéo d'arrière-plan.");
      return;
    }
    if (!s.audioReady || s.loadingVerses) {
      _setGenerationError("Le contenu ou l'audio n'est pas encore prêt.");
      return;
    }
    await stopPreview();
    try {
      final number = await _settings.nextVideoNumber();
      final fileName = buildVideoFileName(
        number: number,
        reciter: s.reciter!,
        chapter: s.chapter!,
        ayahFrom: s.ayahFrom,
        ayahTo: s.ayahTo,
      );
      await _generator.generate(
        outputFileName: fileName,
        clips: s.clips,
        verses: s.verses,
        audios: s.audios,
        style: s.style,
        fadeColor: s.fadeColor,
        transition: s.transition,
        quality: s.quality,
        yFraction: s.yFraction,
        signature: s.signature,
        onState: (g) => state = state.copyWith(generation: g),
      );
    } catch (e) {
      _setGenerationError('Échec de la génération : $e');
    }
  }

  void cancelGeneration() => _generator.cancel();

  void resetGeneration() {
    state = state.copyWith(generation: const GenerationState.idle());
  }

  void _setGenerationError(String message) {
    state = state.copyWith(
      generation: GenerationState(GenerationPhase.error, message: message),
    );
  }
}
