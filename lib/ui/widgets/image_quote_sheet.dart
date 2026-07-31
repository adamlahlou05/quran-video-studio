import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/image_quote_renderer.dart';
import '../../providers/editor_controller.dart';

/// Export d'une image-citation PNG : choix du verset (dans la plage chargée)
/// et du fond dégradé, rendu par le même peintre que l'aperçu/la vidéo,
/// enregistrement dans l'album NUQTA de la galerie.
class ImageQuoteSheet extends ConsumerStatefulWidget {
  const ImageQuoteSheet({super.key});

  @override
  ConsumerState<ImageQuoteSheet> createState() => _ImageQuoteSheetState();
}

class _ImageQuoteSheetState extends ConsumerState<ImageQuoteSheet> {
  int _verseIndex = 0;
  QuoteBackground _background = QuoteBackground.night;
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fileName = await ref
          .read(editorProvider.notifier)
          .exportQuoteImage(verseIndex: _verseIndex, background: _background);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image enregistrée dans la galerie : $fileName'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Export impossible — $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verses = ref.watch(editorProvider.select((s) => s.verses));
    if (_verseIndex >= verses.length) _verseIndex = 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Image-citation (PNG)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Une image fixe 1080×1920 du verset, avec ton style et ta '
            'signature actuels — idéale pour les posts non-vidéo.',
            style: TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
          if (verses.length > 1) ...[
            const SizedBox(height: 12),
            const Text('Verset',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: verses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ChoiceChip(
                  label: Text('V${verses[i].number}'),
                  selected: _verseIndex == i,
                  onSelected: (_) => setState(() => _verseIndex = i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Fond',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final bg in QuoteBackground.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: bg.top,
                    radius: 8,
                  ),
                  label: Text(bg.label),
                  selected: _background == bg,
                  onSelected: (_) => setState(() => _background = bg),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ],
          const SizedBox(height: 14),
          _busy
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44)),
                  onPressed: verses.isEmpty ? null : _export,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text("Enregistrer l'image dans la galerie"),
                ),
        ],
      ),
    );
  }
}
