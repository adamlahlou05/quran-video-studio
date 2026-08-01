/// Analyse de la sortie du filtre FFmpeg `silencedetect` pour rogner les
/// silences de BORD des fichiers audio par verset (continuité entre versets).
///
/// Philosophie très conservatrice : on ne coupe que du silence détecté, on en
/// garde une marge, on plafonne les coupes, et au moindre doute on ne coupe
/// rien. L'intégrité de la récitation prime sur la fluidité.
class SilenceTrim {
  /// Marge de silence conservée de chaque côté (évite de rogner une attaque).
  static const int keepMarginMs = 60;

  /// Coupe maximale autorisée en tête / en queue.
  static const int maxLeadTrimMs = 500;
  static const int maxTailTrimMs = 800;

  /// Durée effective minimale après rognage : en dessous, on ne rogne pas.
  static const int minKeptMs = 400;

  /// Paramètres du filtre (seuil bas et fenêtre courte = prudents).
  static const String filterSpec = 'silencedetect=noise=-40dB:d=0.12';

  /// Extrait (inMs, outMs) depuis la sortie de silencedetect.
  /// [log] : sortie complète de FFmpeg ; [fileDurationMs] : durée du fichier.
  static (int, int) parse(String log, int fileDurationMs) {
    var inMs = 0;
    var outMs = fileDurationMs;

    final starts = _matches(log, 'silence_start');
    final ends = _matches(log, 'silence_end');

    // Silence de tête : commence à ~0 ; sa fin donne la coupe possible.
    if (starts.isNotEmpty && starts.first <= 80) {
      final leadEnd = ends.isNotEmpty && ends.first > starts.first
          ? ends.first
          : 0;
      if (leadEnd > keepMarginMs) {
        inMs = (leadEnd - keepMarginMs).clamp(0, maxLeadTrimMs);
      }
    }

    // Silence de queue : dernier silence_start dont la fin atteint (ou
    // dépasse) la fin du fichier, ou qui n'a pas de silence_end (EOF).
    if (starts.isNotEmpty) {
      final lastStart = starts.last;
      final closedByEnd =
          ends.isNotEmpty && ends.last >= lastStart && ends.last < fileDurationMs - 80;
      if (!closedByEnd && lastStart > inMs) {
        final cut = (lastStart + keepMarginMs).clamp(0, fileDurationMs);
        final maxCutStart = fileDurationMs - maxTailTrimMs;
        outMs = cut < maxCutStart ? maxCutStart : cut;
      }
    }

    if (outMs - inMs < minKeptMs || outMs <= inMs) {
      return (0, fileDurationMs);
    }
    return (inMs, outMs);
  }

  /// Toutes les valeurs (en ms) de `key: <secondes>` dans la sortie.
  static List<int> _matches(String log, String key) {
    final regex = RegExp('$key\\s*:\\s*(-?\\d+(?:\\.\\d+)?)');
    return [
      for (final m in regex.allMatches(log))
        (double.parse(m.group(1)!) * 1000).round(),
    ];
  }
}
