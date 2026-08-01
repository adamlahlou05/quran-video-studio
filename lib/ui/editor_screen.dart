import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/strings.dart';
import 'widgets/control_panel.dart';
import 'widgets/video_canvas.dart';

/// Écran unique de l'application (exigence "Single Screen Editor") :
/// canvas vidéo 9:16 en haut, panneau de contrôle à onglets en bas.
/// Au tout premier lancement, propose le choix de la langue (FR/EN/AR).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _languageDialogShown = false;

  @override
  void initState() {
    super.initState();
    // Petite latence : le chargement du réglage persisté est local et
    // quasi immédiat — les utilisateurs existants ne voient jamais le
    // dialogue.
    Future.delayed(const Duration(milliseconds: 500), _maybeAskLanguage);
  }

  void _maybeAskLanguage() {
    if (!mounted || _languageDialogShown) return;
    if (ref.read(appLanguageProvider).chosen) return;
    _languageDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF161B1E),
        title: const Text(
          'Choisis ta langue · Choose your language · اختر لغتك',
          style: TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final lang in AppLanguage.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FilledButton.tonal(
                  onPressed: () {
                    ref
                        .read(appLanguageProvider.notifier)
                        .setLanguage(lang);
                    Navigator.pop(dialogContext);
                  },
                  child: Text(lang.nativeLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: const [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: VideoCanvas(),
              ),
            ),
            ControlPanel(),
          ],
        ),
      ),
    );
  }
}
