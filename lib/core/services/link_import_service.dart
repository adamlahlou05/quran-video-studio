import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Plateforme reconnue dans un lien collé par l'utilisateur.
enum LinkSource {
  tiktok('TikTok'),
  youtube('YouTube'),
  instagram('Instagram'),
  direct('Lien direct vers un fichier vidéo'),
  unknown('Source inconnue');

  final String label;
  const LinkSource(this.label);
}

/// Détection de la plateforme d'un lien. Pure (couverte par les tests).
///
/// TikTok/YouTube/Instagram sont détectés pour informer l'utilisateur, mais
/// AUCUN téléchargement n'est tenté pour ces plateformes : elles n'offrent
/// pas d'API officielle de téléchargement de vidéos tierces, et l'application
/// ne contourne ni protections ni conditions d'utilisation. Seuls les liens
/// directs vers un fichier vidéo (contenus personnels, banques libres de
/// droits…) sont téléchargeables.
LinkSource detectLinkSource(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return LinkSource.unknown;
  }
  final host = uri.host.toLowerCase();
  if (host == 'tiktok.com' || host.endsWith('.tiktok.com')) {
    return LinkSource.tiktok;
  }
  if (host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be') {
    return LinkSource.youtube;
  }
  if (host == 'instagram.com' || host.endsWith('.instagram.com')) {
    return LinkSource.instagram;
  }
  final path = uri.path.toLowerCase();
  const videoExtensions = ['.mp4', '.mov', '.m4v', '.webm', '.mkv', '.3gp'];
  if (videoExtensions.any(path.endsWith)) {
    return LinkSource.direct;
  }
  return LinkSource.unknown;
}

/// Téléchargement en flux d'un fichier vidéo accessible par lien direct,
/// avec progression réelle (basée sur Content-Length quand il est fourni).
class LinkImportService {
  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _chunkTimeout = Duration(seconds: 30);

  /// Télécharge [url] vers le dossier imports de l'application et renvoie le
  /// fichier. [onProgress] reçoit une fraction 0..1, ou null si la taille
  /// totale est inconnue.
  Future<File> download(
    String url, {
    required void Function(double? progress) onProgress,
  }) async {
    final client = http.Client();
    File? file;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url.trim())))
          .timeout(_connectTimeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.startsWith('text/')) {
        throw Exception("ce lien renvoie une page web, pas un fichier vidéo");
      }
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/imports');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      file = File(
          '${dir.path}/import_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final sink = file.openWrite();
      final total = response.contentLength;
      var received = 0;
      try {
        await for (final chunk
            in response.stream.timeout(_chunkTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(total == null || total <= 0 ? null : received / total);
        }
      } finally {
        await sink.close();
      }
      if (received < 10 * 1024) {
        throw Exception('fichier trop petit pour être une vidéo');
      }
      return file;
    } catch (e) {
      if (file != null && await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Nettoyage best-effort.
        }
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
