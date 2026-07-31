import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

/// Sondage FFprobe local : durée réelle d'un média, sans copie ni conversion.
/// C'est la seule « préparation » qu'impose l'application après la sélection
/// d'une vidéo — quelques dizaines de millisecondes, même sur un gros fichier
/// (seuls les en-têtes sont lus). Le dialogue système « Prêt(s) : 0 sur 1 »
/// appartient au sélecteur photos d'Android (téléchargement cloud éventuel),
/// pas à l'application.
class MediaProbe {
  static Future<int?> durationMs(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final duration =
        double.tryParse(session.getMediaInformation()?.getDuration() ?? '');
    if (duration == null || duration <= 0) return null;
    return (duration * 1000).round();
  }
}
