import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/reciter_catalog.dart';
import '../../providers/editor_controller.dart';
import '../../providers/editor_state.dart';

/// Onglet 2 — Quick Switch des récitateurs : recherche (latin ou arabe,
/// tolérante aux accents et aux harakat), liste horizontale, le changement
/// relance immédiatement la mise en cache audio de la plage sélectionnée.
/// Le catalogue est statique et vérifié : aucun récitateur affiché sans
/// source audio réellement exploitable.
class ReciterTab extends ConsumerStatefulWidget {
  const ReciterTab({super.key});

  @override
  ConsumerState<ReciterTab> createState() => _ReciterTabState();
}

class _ReciterTabState extends ConsumerState<ReciterTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(recitersProvider);
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final favorites = editor.favoriteReciters;
    // Favoris épinglés en tête (dans l'ordre du catalogue), puis les autres.
    final filtered = [
      for (final reciter in all)
        if (reciterMatches(reciter, _query)) reciter,
    ];
    final list = [
      for (final r in filtered)
        if (favorites.contains(r.id)) r,
      for (final r in filtered)
        if (!favorites.contains(r.id)) r,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText:
                    'Rechercher parmi ${all.length} récitateurs (ex. Yasser, سديس)…',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: list.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun récitateur ne correspond à cette recherche.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final reciter = list[index];
                    final selected = editor.reciter?.id == reciter.id;
                    final isFavorite = favorites.contains(reciter.id);
                    final scheme = Theme.of(context).colorScheme;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => notifier.setReciter(reciter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 118,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primaryContainer
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -6,
                              right: -6,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => notifier
                                    .toggleFavoriteReciter(reciter.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 18,
                                    color: isFavorite
                                        ? Colors.amber
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: selected
                                  ? scheme.primary
                                  : _avatarColor(reciter.id),
                              child: Text(
                                _initials(reciter.name),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Text(
                                reciter.displayName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              reciter.arabicName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _AudioStatus(editor: editor, notifier: notifier),
        ),
      ],
    );
  }

  /// Avatar de repli : couleur stable dérivée de l'identifiant du récitateur
  /// (pas de dépendance à une API de photos fragile — voir README).
  static Color _avatarColor(String id) {
    final hue = (id.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor();
  }

  static String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _AudioStatus extends StatelessWidget {
  final EditorState editor;
  final EditorController notifier;
  const _AudioStatus({required this.editor, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (editor.loadingAudio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
              value: editor.audioProgress == 0 ? null : editor.audioProgress),
          const SizedBox(height: 6),
          Text(
            'Mise en cache audio… ${(editor.audioProgress * 100).round()} %',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      );
    }
    if (editor.audioError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              editor.audioError!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: notifier.reloadAudio,
            child: const Text('Réessayer'),
          ),
        ],
      );
    }
    if (editor.audioReady) {
      return const Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Audio en cache — prêt pour l'aperçu et la génération",
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      );
    }
    return const Text(
      'Sélectionne un récitateur pour précharger l’audio.',
      style: TextStyle(fontSize: 12, color: Colors.white54),
    );
  }
}
