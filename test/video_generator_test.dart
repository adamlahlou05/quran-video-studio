import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/models/models.dart';
import 'package:quran_video_studio/core/services/video_generator.dart';

void main() {
  String build(int totalMs, FadeColor color) => VideoGenerator.buildFilter(
        subtitlesPath: '/tmp/subs.ass',
        fontsDir: '/tmp/fonts',
        totalMs: totalMs,
        fadeColor: color,
      );

  test('structure du filtre : échelle 9:16, sous-titres, sortie [v]', () {
    final filter = build(30000, FadeColor.black);
    expect(filter, startsWith('[0:v]scale=1080:1920'));
    expect(filter, contains('crop=1080:1920'));
    expect(filter,
        contains("subtitles=filename='/tmp/subs.ass':fontsdir='/tmp/fonts'"));
    expect(filter, endsWith('[v]'));
  });

  test('fondu noir : 0,9 s placées à la fin de la récitation', () {
    expect(build(30000, FadeColor.black),
        contains('fade=t=out:st=29.100:d=0.900:color=black'));
  });

  test('fondu blanc sélectionnable', () {
    expect(build(30000, FadeColor.white), contains(':color=white'));
  });

  test('récitation courte : fondu réduit à 0,5 s', () {
    expect(build(5000, FadeColor.black),
        contains('fade=t=out:st=4.500:d=0.500:color=black'));
  });

  test('récitation très courte (< 3 s) : pas de fondu', () {
    expect(build(2000, FadeColor.black), isNot(contains('fade=')));
  });

  test('le fondu est appliqué après les sous-titres (le texte fond aussi)', () {
    final filter = build(30000, FadeColor.black);
    expect(filter.indexOf('subtitles='), lessThan(filter.indexOf('fade=')));
  });
}
