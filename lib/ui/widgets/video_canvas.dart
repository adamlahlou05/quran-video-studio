import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../providers/editor_controller.dart';
import 'overlay_block.dart';

/// Aperçu 9:16 : vidéo de fond en boucle (muette), bloc de texte déplaçable
/// verticalement (drag & drop avec aimantation Haut / Milieu / Bas), et
/// commandes d'aperçu audio.
class VideoCanvas extends ConsumerStatefulWidget {
  const VideoCanvas({super.key});

  @override
  ConsumerState<VideoCanvas> createState() => _VideoCanvasState();
}

class _VideoCanvasState extends ConsumerState<VideoCanvas> {
  VideoPlayerController? _video;
  String? _videoPath;
  bool _dragging = false;

  Future<void> _syncVideo(String? path) async {
    if (path == _videoPath) return;
    _videoPath = path;
    final old = _video;
    _video = null;
    if (mounted) setState(() {});
    await old?.dispose();
    if (path == null) return;
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      return;
    }
    await controller.setLooping(true);
    await controller.setVolume(0);
    await controller.play();
    if (!mounted || _videoPath != path) {
      await controller.dispose();
      return;
    }
    setState(() => _video = controller);
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      ref.read(editorProvider.notifier).setBackground(picked.path);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      editorProvider.select((s) => s.backgroundPath),
      (_, path) => _syncVideo(path),
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
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: video.value.size.width,
                      height: video.value.size.height,
                      child: VideoPlayer(video),
                    ),
                  )
                else
                  _Placeholder(onPick: _pickVideo),

                // Guides d'aimantation pendant le drag.
                if (_dragging)
                  for (final snap in kSnapFractions)
                    Positioned(
                      left: 24,
                      right: 24,
                      top: snap * canvasH,
                      child: Container(height: 1, color: Colors.white38),
                    ),

                // Bloc de texte : centre exactement à yFraction * hauteur,
                // comme le \pos(540, y) du fichier ASS final.
                Positioned(
                  left: 12,
                  right: 12,
                  top: editor.yFraction * canvasH,
                  child: FractionalTranslation(
                    translation: const Offset(0, -0.5),
                    child: GestureDetector(
                      onVerticalDragStart: (_) =>
                          setState(() => _dragging = true),
                      onVerticalDragUpdate: (details) => notifier.setYFraction(
                          editor.yFraction + details.delta.dy / canvasH),
                      onVerticalDragEnd: (_) {
                        setState(() => _dragging = false);
                        notifier.snapY();
                      },
                      child: OverlayBlock(
                        state: editor,
                        canvasWidth: canvasW,
                      ),
                    ),
                  ),
                ),

                // Rappel sourate / récitateur en haut du canvas.
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
                    ],
                  ),
                ),

                if (editor.backgroundPath != null)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Changer la vidéo de fond',
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_library_outlined, size: 20),
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

class _Placeholder extends StatelessWidget {
  final VoidCallback onPick;
  const _Placeholder({required this.onPick});

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
          const Icon(Icons.movie_outlined, size: 56, color: Colors.white38),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Importe une vidéo verticale (9:16)\ndepuis ta galerie',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Importer une vidéo'),
          ),
        ],
      ),
    );
  }
}
