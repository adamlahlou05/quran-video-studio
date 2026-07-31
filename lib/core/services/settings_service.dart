import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'export_naming.dart';

/// Réglages persistants légers (fichier JSON dans le stockage interne de
/// l'application — survit aux mises à jour, pas à une désinstallation :
/// dans ce cas la numérotation repart proprement à 001).
class SettingsService {
  Map<String, dynamic>? _cache;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final file = await _file();
      if (await file.exists()) {
        _cache = json.decode(await file.readAsString()) as Map<String, dynamic>;
        return _cache!;
      }
    } catch (_) {
      // Fichier corrompu : on repart de réglages neufs.
    }
    _cache = <String, dynamic>{};
    return _cache!;
  }

  Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode(_cache ?? {}), flush: true);
    } catch (_) {
      // Persistance best-effort : l'app reste fonctionnelle sans.
    }
  }

  /// Prochain numéro de vidéo (1, 2, 3…), incrémenté et persisté.
  Future<int> nextVideoNumber() async {
    final data = await _load();
    final next = (data['videoCounter'] as int? ?? 0) + 1;
    data['videoCounter'] = next;
    await _save();
    return next;
  }

  Future<String> loadHashtags() async {
    final data = await _load();
    return data['hashtags'] as String? ?? kDefaultHashtags;
  }

  Future<void> saveHashtags(String value) async {
    final data = await _load();
    data['hashtags'] = value;
    await _save();
  }
}
