import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// libass (filtre `subtitles` de FFmpeg) lit les polices depuis un dossier du
/// système de fichiers (`fontsdir`), pas depuis les assets Flutter. Ce service
/// extrait donc les .ttf embarqués vers <app_support>/fonts une seule fois.
class FontService {
  static const List<String> _fontAssets = [
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Amiri-Bold.ttf',
    'assets/fonts/ScheherazadeNew-Regular.ttf',
  ];

  /// Renvoie le chemin du dossier de polices utilisable comme `fontsdir`.
  Future<String> ensureFontsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/fonts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    for (final asset in _fontAssets) {
      final file = File('${dir.path}/${asset.split('/').last}');
      if (await file.exists() && await file.length() > 0) continue;
      final data = await rootBundle.load(asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return dir.path;
  }
}
