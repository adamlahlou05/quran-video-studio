import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../providers/editor_controller.dart';

/// Onglet 4 — Génération : récapitulatif, bouton de rendu, barre de
/// progression FFmpeg, annulation, et confirmation d'enregistrement galerie.
class GenerateTab extends ConsumerWidget {
  const GenerateTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final gen = editor.generation;
    final chapter = editor.chapter;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryRow(
                icon: Icons.menu_book_outlined,
                text: chapter == null
                    ? 'Aucune sourate sélectionnée'
                    : 'Sourate ${chapter.nameSimple}, versets '
                        '${editor.ayahFrom} à ${editor.ayahTo}',
              ),
              _SummaryRow(
                icon: Icons.record_voice_over_outlined,
                text: editor.reciter?.displayName ?? 'Aucun récitateur',
              ),
              _SummaryRow(
                icon: Icons.timer_outlined,
                text: editor.audioReady
                    ? 'Durée estimée : ${_formatMs(editor.totalDurationMs)}'
                    : 'Durée estimée : — (audio en préparation)',
              ),
              _SummaryRow(
                icon: Icons.video_file_outlined,
                text: editor.backgroundPath == null
                    ? 'Aucune vidéo de fond importée'
                    : 'Vidéo de fond prête (1080×1920, recadrage auto)',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (gen.phase == GenerationPhase.rendering ||
            gen.phase == GenerationPhase.saving) ...[
          LinearProgressIndicator(
            value: gen.phase == GenerationPhase.saving ? null : gen.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Text(gen.message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: notifier.cancelGeneration,
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
          ),
        ] else if (gen.phase == GenerationPhase.done) ...[
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.greenAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(gen.message,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Album « Quran Video Studio » de ta galerie.',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: notifier.resetGeneration,
            icon: const Icon(Icons.replay),
            label: const Text('Générer une autre vidéo'),
          ),
        ] else ...[
          if (gen.phase == GenerationPhase.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                gen.message,
                style:
                    const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ),
          // Fondu appliqué sur les derniers instants de la vidéo finale
          // (la vidéo est coupée ou bouclée à la durée exacte de la
          // récitation, puis fond vers cette couleur).
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fondu de fin',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final fade in FadeColor.values)
                      ChoiceChip(
                        label: Text(fade.label),
                        selected: editor.fadeColor == fade,
                        onSelected: (_) => notifier.setFadeColor(fade),
                      ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: editor.readyToGenerate ? notifier.generate : null,
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Générer la vidéo'),
          ),
          if (!editor.readyToGenerate)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _missingHint(editor.backgroundPath == null,
                    !editor.audioReady || editor.loadingVerses),
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
        ],
      ],
    );
  }

  static String _missingHint(bool missingVideo, bool missingContent) {
    final parts = <String>[
      if (missingVideo) 'importer une vidéo de fond (canvas en haut)',
      if (missingContent) 'attendre la fin du chargement versets/audio',
    ];
    return 'Avant de générer : ${parts.join(' · ')}.';
  }

  static String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m min ${s.toString().padLeft(2, '0')} s';
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SummaryRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white60),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
