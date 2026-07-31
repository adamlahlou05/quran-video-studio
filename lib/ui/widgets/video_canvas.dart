import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/models.dart';
import '../../providers/editor_controller.dart';
import 'overlay_block.dart';

/// Aperçu 9:16 : vidéos de fond enchaînées (muettes), bloc de texte
/// déplaçable verticalement (drag & drop avec aimantation Haut/Milieu/Bas),
/// et commandes d'aperçu audio.
class VideoCanvas extends ConsumerStatefulWidget {
  const VideoCanvas({super.key});

  @override
  ConsumerState<VideoCanvas> createState() => _VideoCanvasState();
}

class _VideoCanvasState extends ConsumerState<VideoCanvas> {
  VideoPlayerController? _video;
  String? _videoPath;
  int _clipIndex = 0;
  bool _advancing = false;
  bool _dragging = false;
  final ValueNotifier<Rect?> _blockRect = ValueNotifier(null);

  Future<void> _syncVideo(String? path, {required bool loop}) async {
    if (path == _videoPath) {
      final video = _video;
      if (video != null) {
        await video.setLooping(loop);
        // Même chemin ajouté deux fois dans la séquence : on relance.
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
    // Fond silencieux garanti (volume 0 ici, et le rendu FFmpeg ne mappe de
    // toute façon jamais l'audio des vidéos importées).
    await controller.setLooping(loop);
    await controller.setVolume(0);
    await controller.play();
    controller.addListener(() => _onTick(controller));
    final old = _video;
    setState(() => _video = controller);
    await old?.dispose();
  }

  /// Rotation des clips en fin de lecture + filet anti-pause système.
  void _onTick(VideoPlayerController controller) {
    if (_video != controller || !mounted) return;
    final value = controller.value;
    if (!value.isInitialized || value.isBuffering) return;
    final clips = ref.read(editorProvider).clips;
    if (value.isCompleted && clips.length > 1) {
      if (_advancing) return;
      _advancing = true;
      _clipIndex = (_clipIndex + 1) % clips.length;
      _syncVideo(clips[_clipIndex].path, loop: false)
          .whenComplete(() => _advancing = false);
    } else if (!value.isPlaying && !value.isCompleted) {
      controller.play();
    }
  }

  void _onClipsChanged(List<BackgroundClip> clips) {
    if (clips.isEmpty) {
      _clipIndex = 0;
      _syncVideo(null, loop: false);
      return;
    }
    final currentIndex = clips.indexWhere((c) => c.path == _videoPath);
    _clipIndex = currentIndex == -1 ? 0 : currentIndex;
    _syncVideo(clips[_clipIndex].path, loop: clips.length <= 1);
  }

  @override
  void dispose() {
    _video?.dispose();
    _blockRect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      editorProvider.select((s) => s.clips),
      (_, clips) => _onClipsChanged(clips),
    );
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
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
                if (video != null && video.value.isInitialized)
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
                else
                  const _Placeholder(),

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

                // Drag & drop vertical du bloc (démarré sur le bloc lui-même).
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

                // Rappel sourate / récitateur / fonds en haut du canvas.
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
                        _Chip('${editor.clips.length} vidéos'),
                    ],
                  ),
                ),

                // Lecture / pause de l'aperçu synchronisé.
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: editor.loadingAudio
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Audio… '
                                  '${(editor.audioProgress * 100).round()} %',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : IconButton.filled(
                            iconSize: 30,
                            tooltip: editor.isPlaying
                                ? "Arrêter l'aperçu"
                                : 'Écouter avec le texte synchronisé',
                            onPressed: editor.audioReady
                                ? () => notifier.togglePreview()
                                : null,
                            icon: Icon(editor.isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
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

/// Écran d'accueil du canvas : identité NUQTA + rappel du parcours d'import
/// (l'ajout de vidéos se fait uniquement via Contenu → Vidéos d'arrière-plan).
class _Placeholder extends StatelessWidget {
  const _Placeholder();

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
            height: 88,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined,
                size: 56, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          const Text(
            'NUQTA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Ajoute une ou plusieurs vidéos de fond :\n'
              'Contenu → Vidéos d’arrière-plan → Ajouter',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
