import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Téléchargement et mise en cache des audios par verset, plus mesure de leur
/// durée exacte via FFprobe (base de la synchronisation texte/audio).
///
/// Robustesse : chaque URL candidate (primaire puis secours) est tentée deux
/// fois avec timeout ; le fichier téléchargé est validé (taille, pas une page
/// HTML d'erreur) puis sondé par FFprobe — un fichier corrompu est supprimé et
/// le téléchargement retenté au lieu d'empoisonner le cache.
class AudioService {
  static const Duration _downloadTimeout = Duration(seconds: 30);
  static const int _attemptsPerUrl = 2;
  static const int _minValidBytes = 1024;

  final http.Client _client = http.Client();

  /// Renvoie l'audio d'un verset (téléchargé si absent du cache) avec sa durée
  /// mesurée. Cache : <app_support>/audio/<reciterId>/<sourate_verset>.mp3
  Future<VerseAudio> fetchVerseAudio({
    required String reciterId,
    required String verseKey,
    required List<String> urls,
  }) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/audio/$reciterId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/${verseKey.replaceAll(':', '_')}.mp3');

    if (await file.exists() && await file.length() >= _minValidBytes) {
      final duration = await _tryProbeMs(file.path);
      if (duration != null) {
        return VerseAudio(
          verseKey: verseKey,
          localPath: file.path,
          durationMs: duration,
        );
      }
      await _deleteQuietly(file); // cache corrompu : on retélécharge
    }

    Object? lastError;
    for (final url in urls) {
      for (var attempt = 0; attempt < _attemptsPerUrl; attempt++) {
        try {
          await _download(url, file);
          final duration = await _tryProbeMs(file.path);
          if (duration == null) {
            throw Exception('fichier audio illisible');
          }
          return VerseAudio(
            verseKey: verseKey,
            localPath: file.path,
            durationMs: duration,
          );
        } catch (e) {
          lastError = e;
          await _deleteQuietly(file);
        }
      }
    }
    throw Exception('téléchargement impossible ($lastError)');
  }

  Future<void> _download(String url, File target) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url)).timeout(_downloadTimeout);
    } on TimeoutException {
      throw Exception('délai de téléchargement dépassé');
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final bytes = response.bodyBytes;
    // Certains CDN renvoient une page HTML d'erreur avec un statut 200 ;
    // la validation fine du contenu audio est faite ensuite par FFprobe.
    if (bytes.length < _minValidBytes || bytes[0] == 0x3C /* '<' */) {
      throw Exception('réponse invalide (pas un fichier audio)');
    }
    await target.writeAsBytes(bytes, flush: true);
  }

  /// Durée d'un fichier audio en millisecondes, ou null s'il est illisible.
  Future<int?> _tryProbeMs(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final duration =
        double.tryParse(session.getMediaInformation()?.getDuration() ?? '');
    if (duration == null || duration <= 0) return null;
    return (duration * 1000).round();
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Suppression best-effort : un résidu sera revalidé au prochain accès.
    }
  }
}
