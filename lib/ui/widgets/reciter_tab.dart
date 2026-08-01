import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/reciter_catalog.dart';
import '../../core/i18n/strings.dart';
import '../../providers/editor_controller.dart';
import '../../providers/editor_state.dart';

/// Onglet 2 — Récitateurs en GRILLE verticale responsive (2-4 colonnes selon
/// la largeur), recherche tolérante (latin/arabe), favoris épinglés en tête.
/// Le catalogue est statique et vérifié : aucun récitateur sans source audio.
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
    final s = ref.watch(sProvider);
    final favorites = editor.favoriteReciters;
    final filtered = [
      for (final reciter in all)
        if (reciterMatches(reciter, _query)) reciter,
    ];
    // Favoris épinglés en tête (dans l'ordre du catalogue), puis les autres.
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
                hintText: s.searchReciters(all.length),
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    s.noReciterMatch,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54),
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final columns =
                      (constraints.maxWidth / 118).floor().clamp(2, 4);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.92,
                    ),
                    itemCount: list.length,
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
                          padding: const EdgeInsets.all(8),
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
                                top: -4,
                                right: -4,
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
                                    radius: 17,
                                    backgroundColor: selected
                                        ? scheme.primary
                                        : _avatarColor(reciter.id),
                                    child: Text(
                                      _initials(reciter.name),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Text(
                                      reciter.displayName,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10.5),
                                    ),
                                  ),
                                  Text(
                                    reciter.arabicName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Amiri',
                                      fontSize: 11,
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
                  );
                }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: _AudioStatus(editor: editor, notifier: notifier, s: s),
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
  final S s;
  const _AudioStatus(
      {required this.editor, required this.notifier, required this.s});

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
            s.audioCaching((editor.audioProgress * 100).round()),
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
            child: Text(s.retry),
          ),
        ],
      );
    }
    if (editor.audioReady) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              s.audioReadyMsg,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      );
    }
    return Text(
      s.selectReciterHint,
      style: const TextStyle(fontSize: 12, color: Colors.white54),
    );
  }
}
