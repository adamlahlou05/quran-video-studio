import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';

/// Réglages : choix de la langue (FR / EN / AR). L'interface bascule
/// immédiatement, y compris en RTL pour l'arabe ; le choix est mémorisé.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sProvider);
    final current = ref.watch(appLanguageProvider).lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/branding/nuqta_logo.png',
                width: 28,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 10),
              Text(s.settingsTitle,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Text(s.languageLabel,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final lang in AppLanguage.values)
            RadioListTile<AppLanguage>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(lang.nativeLabel,
                  style: const TextStyle(fontSize: 14)),
              value: lang,
              groupValue: current,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(appLanguageProvider.notifier)
                      .setLanguage(value);
                }
              },
            ),
        ],
      ),
    );
  }
}
