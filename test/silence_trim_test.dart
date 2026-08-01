import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/services/silence_trim.dart';

void main() {
  const tag = '[silencedetect @ 0x1]';

  test('silences de tête et de queue rognés avec marge', () {
    final log = '$tag silence_start: 0\n'
        '$tag silence_end: 0.42 | silence_duration: 0.42\n'
        '$tag silence_start: 5.1\n';
    expect(SilenceTrim.parse(log, 5600), (360, 5160));
  });

  test('aucun silence détecté → aucun rognage', () {
    expect(SilenceTrim.parse('', 4000), (0, 4000));
  });

  test('silence au milieu (pause de récitation) → intouché', () {
    final log = '$tag silence_start: 2.0\n'
        '$tag silence_end: 2.5 | silence_duration: 0.5\n';
    expect(SilenceTrim.parse(log, 6000), (0, 6000));
  });

  test('coupes plafonnées (tête 500 ms, queue 800 ms)', () {
    final leadLog = '$tag silence_start: 0\n'
        '$tag silence_end: 2.0 | silence_duration: 2.0\n';
    expect(SilenceTrim.parse(leadLog, 8000).$1, 500);

    final tailLog = '$tag silence_start: 8.0\n';
    expect(SilenceTrim.parse(tailLog, 10000).$2, 9200);
  });

  test('fichier trop court après rognage → aucun rognage (prudence)', () {
    final log = '$tag silence_start: 0\n'
        '$tag silence_end: 0.5 | silence_duration: 0.5\n';
    expect(SilenceTrim.parse(log, 600), (0, 600));
  });
}
