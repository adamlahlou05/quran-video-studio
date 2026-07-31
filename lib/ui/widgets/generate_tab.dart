import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/models.dart';
import '../../core/services/export_naming.dart';
import '../../providers/editor_controller.dart';

/// Onglet 4 — Génération : récapitulatif, bouton de rendu, barre de
/// progression FFmpeg (avec temps restant estimé), annulation, confirmation
/// d'enregistrement, description de partage prête à coller et partage.
class GenerateTab extends ConsumerStatefulWidget {
  const GenerateTab({super.key});

  @override
  ConsumerState<GenerateTab> createState() => _GenerateTabState();
}

class _GenerateTabState extends ConsumerState<GenerateTab> {
  TextEditingController? _tagsController;
  final FocusNode _tagsFocus = FocusNode();

  @override
  void dispose() {
    _tagsController?.dispose();
    _tagsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final gen = editor.generation;
    final chapter = editor.chapter;

    _tagsController ??= TextEditingController(text: editor.hashtags);
    // Les hashtags persistés arrivent après le premier build : on synchronise
    // le champ tant que l'utilisateur n'est pas en train d'y écrire.
    ref.listen(editorProvider.select((s) => s.hashtags), (_, next) {
      if (!_tagsFocus.hasFocus && _tagsController!.text != next) {
        _tagsController!.text = next;
      }
    });

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
                text: editor.clips.isEmpty
                    ? 'Aucune vidéo de fond importée'
                    : '${editor.clips.length} vidéo(s) de fond, '
                        '${_formatMs(editor.clipsTotalMs)} au total '
                        '(1080×1920, recadrage auto)',
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
          // Description prête à coller sur TikTok/Instagram/YouTube : le
          // partage Android ne peut pas pré-remplir la légende côté réseau
          // social, le presse-papiers est le chemin fiable.
          if (editor.reciter != null && chapter != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                buildShareDescription(
                  reciter: editor.reciter!,
                  chapter: chapter,
                  ayahFrom: editor.ayahFrom,
                  ayahTo: editor.ayahTo,
                  hashtags: editor.hashtags,
                ),
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: gen.outputPath == null
                    ? null
                    : () => Share.shareXFiles([XFile(gen.outputPath!)]),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Partager'),
              ),
              OutlinedButton.icon(
                onPressed: editor.reciter == null || chapter == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                          text: buildShareDescription(
                            reciter: editor.reciter!,
                            chapter: chapter,
                            ayahFrom: editor.ayahFrom,
                            ayahTo: editor.ayahTo,
                            hashtags: editor.hashtags,
                          ),
                        ));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Description copiée — colle-la '
                                    'dans TikTok/Instagram/YouTube.')),
                          );
                        }
                      },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier la description'),
              ),
              TextButton.icon(
                onPressed: notifier.resetGeneration,
                icon: const Icon(Icons.replay),
                label: const Text('Autre vidéo'),
              ),
            ],
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
            padding: const EdgeInsets.only(bottom: 6),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Qualité d'export",
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final quality in ExportQuality.values)
                      ChoiceChip(
                        label: Text(quality.label),
                        selected: editor.quality == quality,
                        onSelected: (_) => notifier.setQuality(quality),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _tagsController,
              focusNode: _tagsFocus,
              onChanged: notifier.setHashtags,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Hashtags de la description de partage',
                labelStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
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
                _missingHint(editor.clips.isEmpty,
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
