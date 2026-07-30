import 'package:flutter/material.dart';

import 'content_tab.dart';
import 'generate_tab.dart';
import 'reciter_tab.dart';
import 'style_tab.dart';

/// Panneau de contrôle inférieur : 4 onglets, tout se règle à la volée sans
/// jamais quitter l'écran (les onglets sont des vues internes, pas des pages).
class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
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
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_outlined, size: 20),
                    text: 'Contenu'),
                Tab(icon: Icon(Icons.record_voice_over_outlined, size: 20),
                    text: 'Récitateur'),
                Tab(icon: Icon(Icons.palette_outlined, size: 20),
                    text: 'Style'),
                Tab(icon: Icon(Icons.movie_creation_outlined, size: 20),
                    text: 'Générer'),
              ],
            ),
            const SizedBox(
              height: 250,
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
