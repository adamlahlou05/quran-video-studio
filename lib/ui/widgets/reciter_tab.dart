import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/editor_controller.dart';
import '../../providers/editor_state.dart';

/// Onglet 2 — Quick Switch des récitateurs : liste horizontale, le changement
/// relance immédiatement la mise en cache audio de la plage sélectionnée.
/// Le catalogue est statique et vérifié : disponible sans réseau, aucun
/// récitateur affiché sans source audio réellement exploitable.
class ReciterTab extends ConsumerWidget {
  const ReciterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recitersProvider);
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Récitateur — ${list.length} disponibles',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final reciter = list[index];
                final selected = editor.reciter?.id == reciter.id;
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
                        color:
                            selected ? scheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 21,
                          backgroundColor: selected
                              ? scheme.primary
                              : _avatarColor(reciter.id),
                          child: Text(
                            _initials(reciter.name),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Text(
                            reciter.displayName,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
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
  /// (pas de dépendance à une API de photos fragile).
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
