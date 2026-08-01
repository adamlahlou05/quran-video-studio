import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/models/models.dart';
import '../../core/services/command_parser.dart';
import '../../core/services/video_generator.dart';
import '../../providers/editor_controller.dart';
import 'color_picker_sheet.dart';

/// Onglet 1 — Commande intelligente (colle une instruction d'IA), sourate et
/// plage de versets, et arrière-plans (vidéos/images ordonnées, ou fond uni).
class ContentTab extends ConsumerWidget {
  const ContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersProvider);
    final editor = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final s = ref.watch(sProvider);

    return chapters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorRetry(
        message: s.chaptersError,
        retryLabel: s.retry,
        onRetry: () => ref.invalidate(chaptersProvider),
      ),
      data: (list) {
        final chapter = editor.chapter;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: [
            _CommandBar(chapters: list),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openChapterPicker(context, ref, list, s),
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
                                ? s.chooseChapter
                                : '${chapter.id}. ${chapter.nameSimple}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          if (chapter != null)
                            Text(
                              '${chapter.translatedName} — '
                              '${s.versesCount(chapter.versesCount)}',
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
                  Text(s.versesLabel,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    s.ayahRange(editor.ayahFrom, editor.ayahTo),
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
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(s.versesLoading,
                        style: const TextStyle(fontSize: 12)),
                  ],
                )
              else if (editor.versesError != null)
                _ErrorRetry(
                  message: editor.versesError!,
                  retryLabel: s.retry,
                  onRetry: notifier.reloadVerses,
                )
              else
                Text(
                  s.versesLoaded(editor.verses.length),
                  style: const TextStyle(
                      fontSize: 12, color: Colors.greenAccent),
                ),
            ],
            const SizedBox(height: 14),
            const _BackgroundSection(),
          ],
        );
      },
    );
  }

  Future<void> _openChapterPicker(
    BuildContext context,
    WidgetRef ref,
    List<Chapter> chapters,
    S s,
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
                  c.nameArabic.contains(query) ||
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
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: s.searchSurahHint,
                      border: const OutlineInputBorder(),
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
                          '${c.translatedName} — '
                          '${s.versesCount(c.versesCount)}',
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

/// Barre de commande : colle « Mishary Alafasy — Al-Baqarah — 42-60 » (généré
/// par une IA ou tapé à la main), NUQTA comprend et prépare la sélection.
class _CommandBar extends ConsumerStatefulWidget {
  final List<Chapter> chapters;
  const _CommandBar({required this.chapters});

  @override
  ConsumerState<_CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends ConsumerState<_CommandBar> {
  final TextEditingController _controller = TextEditingController();
  CommandResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse(String input) {
    setState(() {
      _result = input.trim().isEmpty
          ? null
          : parseCommand(
              input,
              chapters: widget.chapters,
              reciters: ref.read(recitersProvider),
            );
    });
  }

  void _apply() {
    final r = _result;
    if (r == null || !r.hasAnything) return;
    ref.read(editorProvider.notifier).applyCommand(
          reciter: r.reciter,
          chapter: r.chapter,
          from: r.from,
          to: r.to,
        );
    setState(() {
      _controller.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sProvider);
    final r = _result;
    final parts = <String>[
      if (r?.reciter != null) r!.reciter!.name,
      if (r?.chapter != null) r!.chapter!.nameSimple,
      if (r?.from != null)
        r!.to == null || r.to == r.from ? '${r.from}' : '${r.from}-${r.to}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _parse,
          onSubmitted: (_) => _apply(),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.auto_awesome, size: 18),
            hintText: s.commandHint,
            hintStyle: const TextStyle(fontSize: 12),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _controller.clear();
                      _parse('');
                    },
                  ),
          ),
        ),
        if (r != null) ...[
          const SizedBox(height: 6),
          if (!r.hasAnything)
            Text(s.commandNotFound,
                style: const TextStyle(
                    fontSize: 11.5, color: Colors.amber))
          else
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 15, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    parts.join(' · '),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _apply,
                  child: Text(s.commandApply,
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          if (r.reciterAlternatives.isNotEmpty ||
              r.chapterAlternatives.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final alt in r.reciterAlternatives)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(alt.displayName,
                          style: const TextStyle(fontSize: 10.5)),
                      onPressed: () => setState(() {
                        _result = CommandResult(
                          reciter: alt,
                          chapter: r.chapter,
                          from: r.from,
                          to: r.to,
                          chapterAlternatives: r.chapterAlternatives,
                        );
                      }),
                    ),
                  for (final alt in r.chapterAlternatives)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(alt.nameSimple,
                          style: const TextStyle(fontSize: 10.5)),
                      onPressed: () => setState(() {
                        _result = CommandResult(
                          reciter: r.reciter,
                          chapter: alt,
                          from: r.from,
                          to: r.to,
                          reciterAlternatives: r.reciterAlternatives,
                        );
                      }),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Arrière-plans : vidéos/images ordonnées (▲/▼, suppression, transition),
/// ou fond uni (couleurs prédéfinies + couleur libre) quand la liste est vide.
class _BackgroundSection extends ConsumerWidget {
  const _BackgroundSection();

  static const List<Color> _solidPresets = [
    Color(0xFF0E1113),
    Color(0xFF15393B),
    Color(0xFF14532D),
    Color(0xFF1E293B),
    Color(0xFF000000),
    Color(0xFFF5F1E8),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(editorProvider.select((st) => st.clips));
    final transition =
        ref.watch(editorProvider.select((st) => st.transition));
    final solidColor =
        ref.watch(editorProvider.select((st) => st.solidColor));
    final totalAudioMs =
        ref.watch(editorProvider.select((st) => st.totalDurationMs));
    final notifier = ref.read(editorProvider.notifier);
    final s = ref.watch(sProvider);
    final scheme = Theme.of(context).colorScheme;

    // Durée par image (ou avertissement si trop d'images).
    String? perImageHint;
    String? imagesWarning;
    if (clips.any((c) => c.isImage) && totalAudioMs > 0) {
      try {
        final durations =
            VideoGenerator.effectiveClipDurationsMs(clips, totalAudioMs);
        final imageIndex = clips.indexWhere((c) => c.isImage);
        perImageHint = s.perImage(
            (durations[imageIndex] / 1000).toStringAsFixed(1));
      } on TooManyImagesException catch (e) {
        imagesWarning = s.errTooManyImages(e.maxImages);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.clipsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: () async {
                final rejected = await notifier.pickAndAddClips();
                if (rejected > 0 && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.rejectedFiles(rejected))));
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(s.addClips),
            ),
          ],
        ),
        if (clips.isEmpty)
          Text(
            s.clipsEmptyHint,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
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
                Icon(
                  clips[i].isImage
                      ? Icons.image_outlined
                      : Icons.videocam_outlined,
                  size: 15,
                  color: Colors.white54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    clips[i].isImage
                        ? '${clips[i].fileName} — ${s.imageBadge}'
                        : '${clips[i].fileName} — '
                            '${_fmtMs(clips[i].durationMs)}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: s.moveUp,
                  onPressed: i == 0 ? null : () => notifier.moveClip(i, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: s.moveDown,
                  onPressed: i == clips.length - 1
                      ? null
                      : () => notifier.moveClip(i, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: s.removeClip,
                  onPressed: () => notifier.removeClip(i),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (imagesWarning != null)
          Text(imagesWarning,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent))
        else if (perImageHint != null)
          Text(perImageHint,
              style:
                  const TextStyle(fontSize: 12, color: Colors.white54)),
        if (clips.length > 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(s.transitionBetween,
                    style: const TextStyle(fontSize: 12.5)),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in TransitionMode.values)
                    ChoiceChip(
                      label: Text(s.transitionLabel(mode)),
                      selected: transition == mode,
                      onSelected: (_) => notifier.setTransition(mode),
                    ),
                ],
              ),
            ],
          ),
        ],
        if (clips.isEmpty) ...[
          const SizedBox(height: 10),
          Text(s.solidTitle,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in _solidPresets)
                GestureDetector(
                  onTap: () => notifier.setSolidColor(color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: solidColor == color
                            ? scheme.primary
                            : Colors.white24,
                        width: solidColor == color ? 3 : 1,
                      ),
                    ),
                    child: solidColor == color
                        ? Icon(
                            Icons.check,
                            size: 15,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
              ActionChip(
                avatar: Icon(Icons.colorize,
                    size: 15,
                    color: solidColor != null &&
                            !_solidPresets.contains(solidColor)
                        ? scheme.primary
                        : null),
                label: Text(s.customColor,
                    style: const TextStyle(fontSize: 11.5)),
                onPressed: () async {
                  final picked = await showModalBottomSheet<Color>(
                    context: context,
                    backgroundColor: const Color(0xFF161B1E),
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => ColorPickerSheet(
                        initial: solidColor ?? const Color(0xFF15393B)),
                  );
                  if (picked != null) notifier.setSolidColor(picked);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _fmtMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _ErrorRetry(
      {required this.message,
      required this.retryLabel,
      required this.onRetry});

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
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
