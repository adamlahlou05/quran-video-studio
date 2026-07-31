import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../providers/editor_controller.dart';
import 'import_link_sheet.dart';

/// Onglet 1 — Sourate et plage de versets.
class ContentTab extends ConsumerWidget {
  const ContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersProvider);
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);

    return chapters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorRetry(
        message: 'Impossible de charger la liste des sourates.',
        onRetry: () => ref.invalidate(chaptersProvider),
      ),
      data: (list) {
        final chapter = editor.chapter;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openChapterPicker(context, ref, list),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter == null
                                ? 'Choisir une sourate'
                                : '${chapter.id}. ${chapter.nameSimple}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          if (chapter != null)
                            Text(
                              '${chapter.translatedName} — '
                              '${chapter.versesCount} versets',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                        ],
                      ),
                    ),
                    if (chapter != null)
                      Text(
                        chapter.nameArabic,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 22),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (chapter != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Versets',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    'Ayah ${editor.ayahFrom} → ${editor.ayahTo}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
              RangeSlider(
                min: 1,
                max: chapter.versesCount.toDouble(),
                divisions: max(1, chapter.versesCount - 1),
                labels: RangeLabels('${editor.ayahFrom}', '${editor.ayahTo}'),
                values: RangeValues(
                  editor.ayahFrom.toDouble(),
                  editor.ayahTo.toDouble(),
                ),
                onChanged: (v) =>
                    notifier.setRange(v.start.round(), v.end.round()),
              ),
              if (editor.loadingVerses)
                const Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Chargement des versets…',
                        style: TextStyle(fontSize: 12)),
                  ],
                )
              else if (editor.versesError != null)
                _ErrorRetry(
                  message: editor.versesError!,
                  onRetry: notifier.reloadVerses,
                )
              else
                Text(
                  '${editor.verses.length} verset(s) chargé(s) ✓',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.greenAccent),
                ),
            ],
            const SizedBox(height: 14),
            const _ClipsSection(),
          ],
        );
      },
    );
  }

  Future<void> _openChapterPicker(
    BuildContext context,
    WidgetRef ref,
    List<Chapter> chapters,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(builder: (context, setSheetState) {
          final filtered = chapters
              .where((c) =>
                  query.isEmpty ||
                  c.nameSimple.toLowerCase().contains(query) ||
                  c.translatedName.toLowerCase().contains(query) ||
                  '${c.id}' == query)
              .toList();
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    autofocus: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher une sourate…',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        setSheetState(() => query = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text('${c.id}',
                              style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text(c.nameSimple),
                        subtitle: Text(
                          '${c.translatedName} — ${c.versesCount} versets',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          c.nameArabic,
                          style: const TextStyle(
                              fontFamily: 'Amiri', fontSize: 20),
                        ),
                        onTap: () {
                          ref
                              .read(editorProvider.notifier)
                              .selectChapter(c);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

/// Séquence des vidéos d'arrière-plan : ordre de lecture modifiable (▲/▼),
/// suppression, ajout, transition optionnelle entre les clips.
class _ClipsSection extends ConsumerWidget {
  const _ClipsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(editorProvider.select((s) => s.clips));
    final transition =
        ref.watch(editorProvider.select((s) => s.transition));
    final notifier = ref.read(editorProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text("Vidéos d'arrière-plan",
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Importer depuis un lien',
              icon: const Icon(Icons.add_link, size: 20),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF161B1E),
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const ImportLinkSheet(),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final rejected = await notifier.pickAndAddClips();
                if (rejected > 0 && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$rejected fichier(s) ignoré(s) : '
                        'pas des vidéos lisibles.'),
                  ));
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        if (clips.isEmpty)
          const Text(
            'Aucune vidéo importée. Elles seront lues dans l’ordre '
            'ci-dessous, en boucle si la récitation est plus longue.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        for (var i = 0; i < clips.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: scheme.primaryContainer,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${clips[i].fileName} — ${_fmtMs(clips[i].durationMs)}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: 'Monter',
                  onPressed: i == 0 ? null : () => notifier.moveClip(i, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: 'Descendre',
                  onPressed: i == clips.length - 1
                      ? null
                      : () => notifier.moveClip(i, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: 'Retirer',
                  onPressed: () => notifier.removeClip(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (clips.length > 1) ...[
          Row(
            children: [
              const Expanded(
                child: Text('Transition entre les vidéos',
                    style: TextStyle(fontSize: 12.5)),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in TransitionMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: transition == mode,
                      onSelected: (_) => notifier.setTransition(mode),
                    ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Durée totale : ${_fmtMs(clips.fold<int>(0, (s, c) => s + c.durationMs))}'
              '${transition == TransitionMode.fade ? ' (fondu croisé 0,5 s)' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ],
      ],
    );
  }

  static String _fmtMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    );
  }
}
