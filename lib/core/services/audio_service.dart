import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'media_probe.dart';
import 'silence_trim.dart';

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

  /// Bornes de rognage déjà calculées, par chemin de fichier (l'analyse
  /// silencedetect n'est faite qu'une fois par fichier et par session).
  static final Map<String, (int, int)> _trimCache = {};

  /// Renvoie l'audio d'un verset (téléchargé si absent du cache) avec sa
  /// durée mesurée et ses bornes de rognage des silences de bord.
  /// Cache : <app_support>/audio/<reciterId>/<sourate_verset>.mp3
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
        return _withTrims(verseKey, file.path, duration);
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
          return _withTrims(verseKey, file.path, duration);
        } catch (e) {
          lastError = e;
          await _deleteQuietly(file);
        }
      }
    }
    throw Exception('téléchargement impossible ($lastError)');
  }

  /// Analyse les silences de bord (une seule fois par fichier) et construit
  /// le VerseAudio. En cas d'échec de l'analyse : aucun rognage (prudence).
  Future<VerseAudio> _withTrims(
      String verseKey, String path, int fileDurationMs) async {
    var trims = _trimCache[path];
    if (trims == null) {
      try {
        final session = await FFmpegKit.executeWithArguments([
          '-hide_banner', '-nostats',
          '-i', path,
          '-af', SilenceTrim.filterSpec,
          '-f', 'null', '-',
        ]);
        final log = await session.getOutput() ?? '';
        trims = SilenceTrim.parse(log, fileDurationMs);
      } catch (_) {
        trims = (0, fileDurationMs);
      }
      _trimCache[path] = trims;
    }
    return VerseAudio(
      verseKey: verseKey,
      localPath: path,
      fileDurationMs: fileDurationMs,
      inMs: trims.$1,
      outMs: trims.$2,
    );
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
  Future<int?> _tryProbeMs(String path) => MediaProbe.durationMs(path);

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Suppression best-effort : un résidu sera revalidé au prochain accès.
    }
  }
}
