import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n/strings.dart';
import '../../core/models/models.dart';
import '../../core/services/export_naming.dart';
import '../../providers/editor_controller.dart';
import 'image_quote_sheet.dart';

/// Onglet 4 — Génération : récapitulatif, rendu avec progression et temps
/// restant, annulation, description de partage prête à coller, partage,
/// et export d'images-citations (une ou toute la plage).
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
    final s = ref.watch(sProvider);
    final gen = editor.generation;
    final chapter = editor.chapter;

    _tagsController ??= TextEditingController(text: editor.hashtags);
    ref.listen(editorProvider.select((st) => st.hashtags), (_, next) {
      if (!_tagsFocus.hasFocus && _tagsController!.text != next) {
        _tagsController!.text = next;
      }
    });

    final backgroundSummary = editor.clips.isNotEmpty
        ? s.clipsSummary(
            editor.clips.length, _formatMs(editor.clipsTotalMs))
        : editor.solidColor != null
            ? s.solidSummary
            : s.noBackground;

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
                    ? s.noChapterSelected
                    : s.chapterSummary(
                        chapter.nameSimple, editor.ayahFrom, editor.ayahTo),
              ),
              _SummaryRow(
                icon: Icons.record_voice_over_outlined,
                text: editor.reciter?.displayName ?? s.noReciter,
              ),
              _SummaryRow(
                icon: Icons.timer_outlined,
                text: editor.audioReady
                    ? s.durationEstimated(_formatMs(editor.totalDurationMs))
                    : s.durationPending,
              ),
              _SummaryRow(
                icon: Icons.video_file_outlined,
                text: backgroundSummary,
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
            label: Text(s.cancel),
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
            s.doneAlbum,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
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
                label: Text(s.share),
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
                              SnackBar(content: Text(s.copied)));
                        }
                      },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(s.copyDesc),
              ),
              TextButton.icon(
                onPressed: notifier.resetGeneration,
                icon: const Icon(Icons.replay),
                label: Text(s.otherVideo),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.fadeLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final fade in FadeColor.values)
                      ChoiceChip(
                        label: Text(s.fadeColorLabel(fade)),
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
                Expanded(
                  child: Text(
                    s.qualityLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final quality in ExportQuality.values)
                      ChoiceChip(
                        label: Text(s.qualityName(quality)),
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
              decoration: InputDecoration(
                isDense: true,
                labelText: s.hashtagsLabel,
                labelStyle: const TextStyle(fontSize: 12),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: editor.readyToGenerate ? notifier.generate : null,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(s.generateBtn),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: editor.verses.isEmpty ||
                    editor.reciter == null ||
                    chapter == null
                ? null
                : () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: const Color(0xFF161B1E),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => const ImageQuoteSheet(),
                    ),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(s.quoteBtn),
          ),
          if (!editor.readyToGenerate)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.missingBefore(
                  editor.clips.isEmpty && editor.solidColor == null,
                  !editor.audioReady || editor.loadingVerses,
                ),
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
        ],
      ],
    );
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
