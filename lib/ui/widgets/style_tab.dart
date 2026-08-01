import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/models/models.dart';
import '../../providers/editor_controller.dart';

/// Onglet 3 — Style et typographie : tout est réactif, l'aperçu se met à jour
/// instantanément (couleur, opacité du fond, traduction, police, taille,
/// signature). L'aperçu et l'export passent par le même peintre.
class StyleTab extends ConsumerStatefulWidget {
  const StyleTab({super.key});

  @override
  ConsumerState<StyleTab> createState() => _StyleTabState();
}

class _StyleTabState extends ConsumerState<StyleTab> {
  static const List<Color> _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD54F),
    Color(0xFF80DEEA),
    Color(0xFFA5D6A7),
    Color(0xFF000000),
  ];

  TextEditingController? _signatureController;
  final FocusNode _signatureFocus = FocusNode();

  @override
  void dispose() {
    _signatureController?.dispose();
    _signatureFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(editorProvider.select((st) => st.style));
    final signature = ref.watch(editorProvider.select((st) => st.signature));
    final notifier = ref.read(editorProvider.notifier);
    final s = ref.watch(sProvider);
    final scheme = Theme.of(context).colorScheme;

    _signatureController ??= TextEditingController(text: signature);
    ref.listen(editorProvider.select((st) => st.signature), (_, next) {
      if (!_signatureFocus.hasFocus && _signatureController!.text != next) {
        _signatureController!.text = next;
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      children: [
        _SectionLabel(s.textColorLabel),
        Row(
          children: [
            for (final color in _colors)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => notifier.setTextColor(color),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: style.textColor == color
                            ? scheme.primary
                            : Colors.white24,
                        width: style.textColor == color ? 3 : 1,
                      ),
                    ),
                    child: style.textColor == color
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        _SectionLabel(s.boxOpacityLabel),
        Slider(
          value: style.boxOpacity,
          min: 0,
          max: 0.9,
          divisions: 18,
          label: '${(style.boxOpacity * 100).round()} %',
          onChanged: notifier.setBoxOpacity,
        ),
        _SectionLabel(s.translationLabel),
        Wrap(
          spacing: 8,
          children: [
            for (final lang in TranslationLang.values)
              ChoiceChip(
                label: Text(s.translationName(lang)),
                selected: style.translation == lang,
                onSelected: (_) => notifier.setTranslation(lang),
              ),
          ],
        ),
        _SectionLabel(s.fontLabelTitle),
        Wrap(
          spacing: 8,
          children: [
            for (final font in ArabicFont.values)
              ChoiceChip(
                label: Text(
                  s.fontLabel(font),
                  style: TextStyle(fontFamily: font.flutterFamily),
                ),
                selected: style.font == font,
                onSelected: (_) => notifier.setFont(font),
              ),
          ],
        ),
        _SectionLabel(s.sizeLabel),
        Slider(
          value: style.sizeScale,
          min: 0.7,
          max: 1.4,
          divisions: 14,
          label: '×${style.sizeScale.toStringAsFixed(1)}',
          onChanged: notifier.setSizeScale,
        ),
        _SectionLabel(s.signatureLabel),
        TextField(
          controller: _signatureController,
          focusNode: _signatureFocus,
          onChanged: notifier.setSignature,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: s.signatureHint,
            hintStyle: const TextStyle(fontSize: 12),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
