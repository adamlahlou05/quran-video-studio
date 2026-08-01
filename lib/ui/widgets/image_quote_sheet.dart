import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/strings.dart';
import '../../core/services/image_quote_renderer.dart';
import '../../providers/editor_controller.dart';
import 'color_picker_sheet.dart';

/// Export d'images-citations PNG : un verset ou TOUTE la plage chargée en une
/// seule opération (génération séquentielle : une image en mémoire à la
/// fois), fond dégradé prédéfini, couleur libre ou image de la galerie.
class ImageQuoteSheet extends ConsumerStatefulWidget {
  const ImageQuoteSheet({super.key});

  @override
  ConsumerState<ImageQuoteSheet> createState() => _ImageQuoteSheetState();
}

class _ImageQuoteSheetState extends ConsumerState<ImageQuoteSheet> {
  int _verseIndex = 0;
  bool _allVerses = false;
  QuoteBackground? _preset = QuoteBackground.night;
  Color? _customColor;
  String? _imagePath;
  bool _busy = false;
  bool _cancelRequested = false;
  String _progressText = '';
  String? _error;

  QuoteBgSpec get _bgSpec {
    if (_imagePath != null) return QuoteBgSpec.image(_imagePath!);
    if (_customColor != null) return QuoteBgSpec.color(_customColor!);
    return QuoteBgSpec.preset(_preset ?? QuoteBackground.night);
  }

  Future<void> _export() async {
    final s = ref.read(sProvider);
    final verses = ref.read(editorProvider).verses;
    final indices =
        _allVerses ? List.generate(verses.length, (i) => i) : [_verseIndex];
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _error = null;
      _progressText = '';
    });
    var saved = 0;
    String? lastName;
    try {
      for (var i = 0; i < indices.length; i++) {
        if (_cancelRequested) break;
        if (mounted) {
          setState(() =>
              _progressText = s.generatingImages(i + 1, indices.length));
        }
        lastName = await ref.read(editorProvider.notifier).exportQuoteImage(
              verseIndex: indices[i],
              background: _bgSpec,
            );
        saved++;
      }
      if (mounted && saved > 0) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved == 1
              ? s.imageSaved(lastName!)
              : s.imagesSaved(saved)),
        ));
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _error = s.exportError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sProvider);
    final verses = ref.watch(editorProvider.select((st) => st.verses));
    if (_verseIndex >= verses.length) _verseIndex = 0;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.quoteTitle,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            s.quoteSubtitle,
            style: const TextStyle(fontSize: 11.5, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          Text(s.verseLabel,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (verses.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s.allVerses(verses.length)),
                      selected: _allVerses,
                      onSelected: (_) =>
                          setState(() => _allVerses = !_allVerses),
                    ),
                  ),
                for (var i = 0; i < verses.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('V${verses[i].number}'),
                      selected: !_allVerses && _verseIndex == i,
                      onSelected: (_) => setState(() {
                        _allVerses = false;
                        _verseIndex = i;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(s.backgroundLabel,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final bg in QuoteBackground.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: bg.top, radius: 8),
                  label: Text(s.quoteBgLabel(bg)),
                  selected: _imagePath == null &&
                      _customColor == null &&
                      _preset == bg,
                  onSelected: (_) => setState(() {
                    _preset = bg;
                    _customColor = null;
                    _imagePath = null;
                  }),
                ),
              ChoiceChip(
                avatar: Icon(Icons.colorize,
                    size: 15,
                    color: _customColor != null ? scheme.primary : null),
                label: Text(s.customColor),
                selected: _customColor != null,
                onSelected: (_) async {
                  final picked = await showModalBottomSheet<Color>(
                    context: context,
                    backgroundColor: const Color(0xFF161B1E),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => ColorPickerSheet(
                        initial: _customColor ?? const Color(0xFF15393B)),
                  );
                  if (picked != null) {
                    setState(() {
                      _customColor = picked;
                      _imagePath = null;
                    });
                  }
                },
              ),
              ChoiceChip(
                avatar: const Icon(Icons.image_outlined, size: 15),
                label: Text(s.pickImage),
                selected: _imagePath != null,
                onSelected: (_) async {
                  final picked = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() {
                      _imagePath = picked.path;
                      _customColor = null;
                    });
                  }
                },
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
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(_progressText,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _cancelRequested = true),
                  child: Text(s.cancel),
                ),
              ],
            ),
          ] else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
              onPressed: verses.isEmpty ? null : _export,
              icon: const Icon(Icons.image_outlined),
              label: Text(_allVerses && verses.length > 1
                  ? s.saveMany(verses.length)
                  : s.saveOne),
            ),
        ],
      ),
    );
  }
}
