import 'package:flutter/material.dart';

import 'widgets/control_panel.dart';
import 'widgets/video_canvas.dart';

/// Écran unique de l'application (exigence "Single Screen Editor") :
/// canvas vidéo 9:16 en haut, panneau de contrôle à onglets en bas.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

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
