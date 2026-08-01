import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/strings.dart';
import '../../core/models/models.dart';
import '../../core/services/video_generator.dart';
import '../../providers/editor_controller.dart';
import '../../providers/editor_state.dart';
import 'overlay_block.dart';
import 'settings_sheet.dart';

/// Aperçu 9:16 : fonds enchaînés (vidéos muettes, images, couleur unie),
/// bloc de texte déplaçable, et timeline interactive synchronisée
/// (audio + verset + fond suivent la même position ; le slider permet de
/// vérifier début, milieu, fin et transitions avant la génération).
class VideoCanvas extends ConsumerStatefulWidget {
  const VideoCanvas({super.key});

  @override
  ConsumerState<VideoCanvas> createState() => _VideoCanvasState();
}

class _VideoCanvasState extends ConsumerState<VideoCanvas> {
  VideoPlayerController? _video;
  String? _videoPath;
  String? _imagePath;
  int _clipIndex = 0;
  bool _advancing = false;
  bool _dragging = false;
  double? _dragValueMs;
  Timer? _imageTimer;
  final ValueNotifier<Rect?> _blockRect = ValueNotifier(null);

  // ─────────────────── Mapping timeline → fond ───────────────────

  List<int> _effDurations(EditorState editor) {
    if (editor.clips.isEmpty) return const [];
    try {
      final total = editor.totalDurationMs;
      if (total > 0) {
        return VideoGenerator.effectiveClipDurationsMs(editor.clips, total);
      }
    } on TooManyImagesException {
      // Trop d'images pour la durée : l'aperçu reste utilisable quand même.
    }
    return [
      for (final c in editor.clips) c.isImage ? 4000 : c.durationMs,
    ];
  }

  (int, int) _mapPosition(int ms, List<int> durations) {
    final cycle = durations.fold<int>(0, (s, d) => s + d);
    if (cycle <= 0 || durations.isEmpty) return (0, 0);
    var t = ms % cycle;
    for (var i = 0; i < durations.length; i++) {
      if (t < durations[i]) return (i, t);
      t -= durations[i];
    }
    return (durations.length - 1, durations.last);
  }

  // ─────────────────── Affichage du clip courant ───────────────────

  Future<void> _showClip(int index, {int? seekMs}) async {
    final editor = ref.read(editorProvider);
    final clips = editor.clips;
    if (clips.isEmpty) {
      _imageTimer?.cancel();
      _imagePath = null;
      await _syncVideo(null, loop: false);
      if (mounted) setState(() {});
      return;
    }
    _clipIndex = index.clamp(0, clips.length - 1);
    final clip = clips[_clipIndex];
    if (clip.isImage) {
      await _syncVideo(null, loop: false);
      if (mounted) setState(() => _imagePath = clip.path);
      _scheduleIdleImageAdvance();
    } else {
      if (_imagePath != null && mounted) {
        setState(() => _imagePath = null);
      }
      _imageTimer?.cancel();
      await _syncVideo(clip.path, loop: clips.length <= 1);
      if (seekMs != null && _video != null) {
        try {
          await _video!.seekTo(Duration(milliseconds: seekMs));
        } catch (_) {
          // Seek best-effort : la vidéo repart sinon du début du clip.
        }
      }
    }
  }

  /// Rotation « ambiance » des images quand la preview n'est pas en lecture.
  void _scheduleIdleImageAdvance() {
    _imageTimer?.cancel();
    final editor = ref.read(editorProvider);
    if (editor.isPlaying || editor.clips.length <= 1) return;
    final durations = _effDurations(editor);
    if (_clipIndex >= durations.length) return;
    _imageTimer = Timer(Duration(milliseconds: durations[_clipIndex]), () {
      final clips = ref.read(editorProvider).clips;
      if (!mounted || clips.length <= 1) return;
      _showClip((_clipIndex + 1) % clips.length);
    });
  }

  Future<void> _syncVideo(String? path, {required bool loop}) async {
    if (path == _videoPath) {
      final video = _video;
      if (video != null) {
        await video.setLooping(loop);
        if (video.value.isCompleted) {
          await video.seekTo(Duration.zero);
          await video.play();
        }
      }
      return;
    }
    _videoPath = path;
    if (path == null) {
      final old = _video;
      if (mounted) setState(() => _video = null);
      await old?.dispose();
      return;
    }
    // mixWithOthers : sans cette option, l'ExoPlayer de video_player gère le
    // focus audio Android et se met en pause dès que just_audio démarre la
    // récitation — c'était la cause du freeze de la vidéo pendant l'aperçu.
    final controller = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      return;
    }
    if (!mounted || _videoPath != path) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(loop);
    await controller.setVolume(0);
    await controller.play();
    controller.addListener(() => _onTick(controller));
    final old = _video;
    setState(() => _video = controller);
    await old?.dispose();
  }

  /// Rotation des vidéos en fin de lecture (mode ambiance) + anti-pause.
  void _onTick(VideoPlayerController controller) {
    if (_video != controller || !mounted) return;
    final value = controller.value;
    if (!value.isInitialized || value.isBuffering) return;
    final editor = ref.read(editorProvider);
    if (value.isCompleted && editor.clips.length > 1 && !editor.isPlaying) {
      if (_advancing) return;
      _advancing = true;
      _showClip((_clipIndex + 1) % editor.clips.length)
          .whenComplete(() => _advancing = false);
    } else if (!value.isPlaying && !value.isCompleted) {
      controller.play();
    }
  }

  void _onClipsChanged(List<BackgroundClip> clips) {
    if (clips.isEmpty) {
      _clipIndex = 0;
      _showClip(0);
      return;
    }
    final currentPath = _imagePath ?? _videoPath;
    final currentIndex = clips.indexWhere((c) => c.path == currentPath);
    _showClip(currentIndex == -1 ? 0 : currentIndex);
  }

  /// Seek explicite : réaligne le fond sur la position de la timeline.
  void _onSeek(int positionMs) {
    final editor = ref.read(editorProvider);
    if (editor.clips.isEmpty) return;
    final durations = _effDurations(editor);
    final (index, offset) = _mapPosition(positionMs, durations);
    _showClip(index, seekMs: offset);
  }

  /// Pendant la lecture, le fond suit la timeline (changements d'images et
  /// enchaînements de vidéos aux mêmes instants que dans l'export).
  void _onPositionChanged(int positionMs) {
    final editor = ref.read(editorProvider);
    if (!editor.isPlaying || editor.clips.length <= 1) return;
    final durations = _effDurations(editor);
    final (index, _) = _mapPosition(positionMs, durations);
    if (index != _clipIndex && !_advancing) {
      _advancing = true;
      _showClip(index).whenComplete(() => _advancing = false);
    }
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _video?.dispose();
    _blockRect.dispose();
    super.dispose();
  }

  static String _fmt(int ms) {
    final s = (ms / 1000).floor();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      editorProvider.select((st) => st.clips),
      (_, clips) => _onClipsChanged(clips),
    );
    ref.listen(
      editorProvider.select((st) => st.previewSeekSeq),
      (_, __) => _onSeek(ref.read(editorProvider).previewPositionMs),
    );
    ref.listen(
      editorProvider.select((st) => st.previewPositionMs),
      (_, ms) => _onPositionChanged(ms),
    );
    ref.listen(
      editorProvider.select((st) => st.isPlaying),
      (_, playing) {
        if (playing) {
          _imageTimer?.cancel();
        } else {
          _scheduleIdleImageAdvance();
        }
      },
    );
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final s = ref.watch(sProvider);
    final video = _video;

    return LayoutBuilder(builder: (context, constraints) {
      final canvasW =
          min(constraints.maxWidth, constraints.maxHeight * 9 / 16);
      final canvasH = canvasW * 16 / 9;

      return Center(
        child: SizedBox(
          width: canvasW,
          height: canvasH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imagePath != null)
                  RepaintBoundary(
                    child: Image.file(
                      File(_imagePath!),
                      fit: BoxFit.cover,
                      cacheHeight: 1440,
                      gaplessPlayback: true,
                    ),
                  )
                else if (video != null && video.value.isInitialized)
                  RepaintBoundary(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: video.value.size.width,
                        height: video.value.size.height,
                        child: VideoPlayer(video),
                      ),
                    ),
                  )
                else if (editor.clips.isEmpty && editor.solidColor != null)
                  Container(color: editor.solidColor)
                else
                  _Placeholder(hint: s.canvasHint),

                // Guides d'aimantation pendant le drag.
                if (_dragging)
                  for (final snap in kSnapFractions)
                    Positioned(
                      left: 24,
                      right: 24,
                      top: snap * canvasH,
                      child: Container(height: 1, color: Colors.white38),
                    ),

                // Texte incrusté : même peintre que l'export (WYSIWYG).
                Positioned.fill(child: OverlayPreview(blockRect: _blockRect)),

                // Drag & drop vertical du bloc (démarré sur le bloc).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (details) {
                      final rect = _blockRect.value;
                      if (rect != null &&
                          rect.inflate(12).contains(details.localPosition)) {
                        setState(() => _dragging = true);
                      }
                    },
                    onVerticalDragUpdate: (details) {
                      if (_dragging) {
                        notifier.setYFraction(
                            editor.yFraction + details.delta.dy / canvasH);
                      }
                    },
                    onVerticalDragEnd: (_) {
                      if (_dragging) {
                        setState(() => _dragging = false);
                        notifier.snapY();
                      }
                    },
                    onVerticalDragCancel: () {
                      if (_dragging) setState(() => _dragging = false);
                    },
                  ),
                ),

                // Rappels en haut du canvas.
                Positioned(
                  left: 10,
                  top: 10,
                  right: 54,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (editor.chapter != null)
                        _Chip(
                            'S${editor.chapter!.id} · '
                            '${editor.chapter!.nameSimple} '
                            '${editor.ayahFrom}-${editor.ayahTo}'),
                      if (editor.reciter != null)
                        _Chip(editor.reciter!.name),
                      if (editor.clips.length > 1)
                        _Chip(s.videosChip(editor.clips.length)),
                    ],
                  ),
                ),

                Positioned(
                  right: 6,
                  top: 6,
                  child: IconButton.filledTonal(
                    tooltip: s.settingsTooltip,
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: const Color(0xFF161B1E),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => const SettingsSheet(),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 20),
                  ),
                ),

                // Timeline interactive.
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: _buildTransport(editor, notifier, s),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTransport(
      EditorState editor, EditorController notifier, S s) {
    Widget chip(Widget child) => Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: child,
          ),
        );

    if (editor.loadingAudio) {
      return chip(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            s.audioLoading((editor.audioProgress * 100).round()),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ));
    }
    // Audio prêt mais texte encore en chargement : état visible (c'était la
    // cause du « Play qui ne fait rien » — bouton grisé sans explication).
    if (!editor.audioReady &&
        (editor.loadingVerses || editor.audios.isNotEmpty)) {
      return chip(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(s.textLoading, style: const TextStyle(fontSize: 12)),
        ],
      ));
    }

    final total = editor.totalDurationMs;
    final position =
        (_dragValueMs ?? editor.previewPositionMs.toDouble())
            .clamp(0.0, max(total.toDouble(), 1.0))
            .toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: editor.isPlaying ? s.pauseTooltip : s.playTooltip,
            onPressed:
                editor.audioReady ? () => notifier.togglePreview() : null,
            icon: Icon(
              editor.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 26,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: 0,
                max: max(total.toDouble(), 1.0),
                value: position,
                onChanged: editor.audioReady
                    ? (v) => setState(() => _dragValueMs = v)
                    : null,
                onChangeEnd: editor.audioReady
                    ? (v) {
                        setState(() => _dragValueMs = null);
                        notifier.seekPreview(v.round());
                      }
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 8),
            child: Text(
              '${_fmt(position.round())} / ${_fmt(total)}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String hint;
  const _Placeholder({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15393B), Color(0xFF0B1D22)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/branding/nuqta_logo.png',
            width: 88,
            errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined,
                size: 56, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          const Text(
            'NUQTA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
