import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/models/models.dart';
import 'package:quran_video_studio/core/services/video_generator.dart';

void main() {
  group('buildFinalFilter (passe 2 : fond + texte + fondu)', () {
    String build(int totalMs, FadeColor color) =>
        VideoGenerator.buildFinalFilter(totalMs: totalMs, fadeColor: color);

    test('structure : normalisation 9:16, overlay du texte, sortie [v]', () {
      final filter = build(30000, FadeColor.black);
      expect(filter, startsWith('[0:v]scale=1080:1920'));
      expect(filter, contains('crop=1080:1920'));
      expect(filter, contains('[bg];[bg][2:v]overlay=0:0'));
      expect(filter, endsWith('[v]'));
    });

    test('fondu noir : 0,9 s placées à la fin de la récitation', () {
      expect(build(30000, FadeColor.black),
          contains('fade=t=out:st=29.100:d=0.900:color=black'));
    });

    test('fondu blanc sélectionnable', () {
      expect(build(30000, FadeColor.white), contains(':color=white'));
    });

    test('récitation courte : fondu réduit ; très courte : aucun', () {
      expect(build(5000, FadeColor.black),
          contains('fade=t=out:st=4.500:d=0.500'));
      expect(build(2000, FadeColor.black), isNot(contains('fade=')));
    });

    test("l'overlay du texte précède le fondu (le texte fond aussi)", () {
      final filter = build(30000, FadeColor.black);
      expect(filter.indexOf('overlay='), lessThan(filter.indexOf('fade=')));
    });
  });

  group('multi-vidéos (passe 1)', () {
    const durations = [10000, 30000, 15000];

    test('offsets xfade sur la timeline de sortie', () {
      expect(VideoGenerator.xfadeOffsets(durations, 0.5), [9.5, 39.0]);
    });

    test('durée de séquence : brute sans fondu, réduite avec', () {
      expect(
          VideoGenerator.sequenceDurationSec(durations, TransitionMode.none),
          55.0);
      expect(
          VideoGenerator.sequenceDurationSec(durations, TransitionMode.fade),
          54.0);
    });

    test('enchaînement direct : concat dans l’ordre choisi', () {
      final filter =
          VideoGenerator.buildSequenceFilter(durations, TransitionMode.none);
      expect(filter, contains('[0:v]scale=1080:1920'));
      expect(filter, contains('[2:v]scale=1080:1920'));
      expect(filter, contains('[p0][p1][p2]concat=n=3:v=1:a=0[seq]'));
    });

    test('fondu croisé : chaîne xfade avec offsets exacts', () {
      final filter =
          VideoGenerator.buildSequenceFilter(durations, TransitionMode.fade);
      expect(filter,
          contains('xfade=transition=fade:duration=0.500:offset=9.500[x1]'));
      expect(filter,
          contains('xfade=transition=fade:duration=0.500:offset=39.000[seq]'));
    });

    test('deux clips : la première transition sort directement en [seq]', () {
      final filter = VideoGenerator.buildSequenceFilter(
          const [8000, 12000], TransitionMode.fade);
      expect(filter,
          contains('xfade=transition=fade:duration=0.500:offset=7.500[seq]'));
    });
  });
}
