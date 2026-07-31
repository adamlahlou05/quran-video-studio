import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/services/overlay_renderer.dart';

void main() {
  test('ffconcat : timings exacts, dernier PNG répété (quirk du démuxeur)',
      () {
    final concat = OverlayRenderer.buildConcat(
      ['/tmp/a.png', '/tmp/b.png'],
      [1500, 2500],
    );
    final lines = concat.trim().split('\n');
    expect(lines, [
      'ffconcat version 1.0',
      "file '/tmp/a.png'",
      'duration 1.500',
      "file '/tmp/b.png'",
      'duration 2.500',
      "file '/tmp/b.png'",
    ]);
  });

  test('ffconcat : un seul verset reste valide', () {
    final concat = OverlayRenderer.buildConcat(['/x/v.png'], [4200]);
    expect(concat, contains('duration 4.200'));
    expect(RegExp("file '/x/v.png'").allMatches(concat).length, 2);
  });
}
