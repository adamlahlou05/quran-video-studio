import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Téléchargement et mise en cache des audios par verset, plus mesure de leur
/// durée exacte via FFprobe (base de la synchronisation texte/audio).
class AudioService {
  final http.Client _client = http.Client();

  /// Télécharge (si absent du cache) l'audio d'un verset et renvoie son chemin
  /// local. Cache : <app_support>/audio/<reciterId>/<sourate_verset>.mp3
  Future<String> ensureVerseAudio({
    required int reciterId,
    required String verseKey,
    required String url,
  }) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/audio/$reciterId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/${verseKey.replaceAll(':', '_')}.mp3');
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
          'Téléchargement audio échoué (HTTP ${response.statusCode})');
    }
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  /// Durée exacte d'un fichier audio en millisecondes.
  Future<int> probeDurationMs(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final duration =
        double.tryParse(session.getMediaInformation()?.getDuration() ?? '');
    if (duration == null || duration <= 0) {
      throw Exception('Durée audio illisible : $path');
    }
    return (duration * 1000).round();
  }
}
