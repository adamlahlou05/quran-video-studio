import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api/quran_api.dart';
import '../core/data/reciter_catalog.dart';
import '../core/i18n/strings.dart';
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

  /// Playlist de preview : identité des audios chargés + départs cumulés.
  List<VerseAudio>? _playlistAudios;
  List<int> _cumStartMs = const [];
  final List<StreamSubscription<dynamic>> _playerSubs = [];

  final Map<String, List<Verse>> _verseCache = {};

  S get _s => ref.read(sProvider);

  @override
  EditorState build() {
    ref.onDispose(() {
      _rangeDebounce?.cancel();
      for (final sub in _playerSubs) {
        sub.cancel();
      }
      _player.dispose();
    });
    // Timeline de preview : le lecteur pilote la position globale, l'index
    // du verset affiché et la fin de lecture.
    _playerSubs.add(_player.currentIndexStream.listen((index) {
      if (index != null && index != state.previewIndex) {
        state = state.copyWith(previewIndex: index);
      }
    }));
    _playerSubs.add(_player.positionStream.listen((position) {
      final index = _player.currentIndex;
      if (index == null || index >= _cumStartMs.length) return;
      final ms = (_cumStartMs[index] + position.inMilliseconds)
          .clamp(0, state.totalDurationMs);
      if ((ms - state.previewPositionMs).abs() >= 120) {
        state = state.copyWith(previewPositionMs: ms);
      }
    }));
    _playerSubs.add(_player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed &&
          state.isPlaying) {
        state = state.copyWith(
          isPlaying: false,
          previewPositionMs: state.totalDurationMs,
        );
      }
    }));
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
      if (duration != null) {
        added.add(BackgroundClip(path: file.path, durationMs: duration));
      } else if (await MediaProbe.isImage(file.path)) {
        // Image fixe : sa durée d'affichage sera calculée à la génération
        // (récitation répartie entre les images).
        added.add(
            BackgroundClip(path: file.path, durationMs: 0, isImage: true));
      } else {
        rejected++;
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

  /// Couleur du fond uni, utilisée quand aucun clip n'est sélectionné.
  void setSolidColor(Color color) {
    state = state.copyWith(solidColor: color);
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
    required QuoteBgSpec background,
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

  /// Sélectionne sourate + plage en une seule passe (un seul rechargement).
  void selectChapterRange(Chapter chapter, int from, int to) {
    stopPreview();
    final safeFrom = from.clamp(1, chapter.versesCount);
    final safeTo = to.clamp(safeFrom, chapter.versesCount);
    state = state.copyWith(
      chapter: chapter,
      ayahFrom: safeFrom,
      ayahTo: safeTo,
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

  /// Applique le résultat de la barre de commande (récitateur / sourate /
  /// plage, chacun optionnel) avec un minimum de rechargements.
  void applyCommand({Reciter? reciter, Chapter? chapter, int? from, int? to}) {
    var reciterChanged = false;
    if (reciter != null && reciter.id != state.reciter?.id) {
      stopPreview();
      state = state.copyWith(
        reciter: reciter,
        audios: const [],
        audioError: null,
      );
      reciterChanged = true;
    }
    if (chapter != null) {
      selectChapterRange(chapter, from ?? 1, to ?? from ?? 5);
    } else if (from != null) {
      final before = (state.ayahFrom, state.ayahTo);
      setRange(from, to ?? from);
      if (reciterChanged && before == (state.ayahFrom, state.ayahTo)) {
        _reloadAudio();
      }
    } else if (reciterChanged) {
      _reloadAudio();
    }
  }

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
        versesError: '${_s.versesUnavailable} — $e',
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
        audioError: _s.audioUnavailable(reciter.name, e),
      );
    }
  }

  // ─────────────────────── Aperçu (timeline interactive) ───────────────────

  /// Construit (si besoin) la playlist de preview : un ClippingAudioSource
  /// par verset, avec les MÊMES bornes de rognage que l'export — position et
  /// seek globaux gérés nativement par just_audio.
  Future<bool> _ensurePlaylist() async {
    if (!state.audioReady) return false;
    final audios = state.audios;
    if (identical(_playlistAudios, audios)) return true;
    final cum = <int>[];
    var acc = 0;
    for (final a in audios) {
      cum.add(acc);
      acc += a.durationMs;
    }
    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: [
          for (final a in audios)
            ClippingAudioSource(
              start: Duration(milliseconds: a.inMs),
              end: Duration(milliseconds: a.outMs),
              child: AudioSource.file(a.localPath),
            ),
        ]),
      );
    } catch (_) {
      state = state.copyWith(audioError: _s.playError);
      return false;
    }
    _cumStartMs = cum;
    _playlistAudios = audios;
    return true;
  }

  Future<void> togglePreview() async {
    if (state.isPlaying) {
      state = state.copyWith(isPlaying: false);
      await _player.pause();
      return;
    }
    if (!await _ensurePlaylist()) return;
    try {
      if (state.previewPositionMs >= state.totalDurationMs) {
        await _player.seek(Duration.zero, index: 0);
        state = state.copyWith(previewPositionMs: 0, previewIndex: 0);
      }
      state = state.copyWith(isPlaying: true, audioError: null);
      unawaited(_player.play().catchError((Object _) {
        state = state.copyWith(isPlaying: false, audioError: _s.playError);
      }));
    } catch (_) {
      state = state.copyWith(isPlaying: false, audioError: _s.playError);
    }
  }

  /// Positionne la preview à [ms] : audio, verset affiché et (via
  /// previewSeekSeq) le fond vidéo/image du canvas.
  Future<void> seekPreview(int ms) async {
    if (!await _ensurePlaylist()) return;
    final target = ms.clamp(0, state.totalDurationMs);
    var index = 0;
    for (var i = 0; i < _cumStartMs.length; i++) {
      if (_cumStartMs[i] <= target) index = i;
    }
    try {
      await _player.seek(
        Duration(milliseconds: target - _cumStartMs[index]),
        index: index,
      );
    } catch (_) {
      return;
    }
    state = state.copyWith(
      previewPositionMs: target,
      previewIndex: index,
      previewSeekSeq: state.previewSeekSeq + 1,
    );
  }

  /// Arrêt + invalidation de la playlist (paramètres modifiés).
  Future<void> stopPreview() async {
    _playlistAudios = null;
    _cumStartMs = const [];
    if (state.isPlaying ||
        state.previewPositionMs != 0 ||
        state.previewIndex != 0) {
      state = state.copyWith(
        isPlaying: false,
        previewIndex: 0,
        previewPositionMs: 0,
        previewSeekSeq: state.previewSeekSeq + 1,
      );
    }
    try {
      await _player.stop();
    } catch (_) {
      // Lecteur déjà arrêté : sans gravité.
    }
  }

  // ─────────────────────────── Génération ───────────────────────────

  Future<void> generate() async {
    final s = state;
    if (s.generation.isBusy) return;
    if (s.clips.isEmpty && s.solidColor == null) {
      _setGenerationError(_s.errNeedBackground);
      return;
    }
    if (!s.audioReady || s.loadingVerses) {
      _setGenerationError(_s.errNotReady);
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
        solidColor: s.solidColor,
        verses: s.verses,
        audios: s.audios,
        style: s.style,
        fadeColor: s.fadeColor,
        transition: s.transition,
        quality: s.quality,
        yFraction: s.yFraction,
        signature: s.signature,
        strings: _s,
        onState: (g) => state = state.copyWith(generation: g),
      );
    } catch (e) {
      _setGenerationError(_s.errGeneric(e));
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
