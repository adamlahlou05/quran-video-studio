import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import 'content_tab.dart';
import 'generate_tab.dart';
import 'reciter_tab.dart';
import 'style_tab.dart';

/// Panneau de contrôle inférieur : 4 onglets, tout se règle à la volée sans
/// jamais quitter l'écran (les onglets sont des vues internes, pas des pages).
class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161B1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 11),
              tabs: [
                Tab(
                    icon: const Icon(Icons.menu_book_outlined, size: 20),
                    text: s.tabContent),
                Tab(
                    icon: const Icon(Icons.record_voice_over_outlined,
                        size: 20),
                    text: s.tabReciter),
                Tab(
                    icon: const Icon(Icons.palette_outlined, size: 20),
                    text: s.tabStyle),
                Tab(
                    icon: const Icon(Icons.movie_creation_outlined,
                        size: 20),
                    text: s.tabGenerate),
              ],
            ),
            const SizedBox(
              height: 300,
              child: TabBarView(
                children: [
                  ContentTab(),
                  ReciterTab(),
                  StyleTab(),
                  GenerateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
