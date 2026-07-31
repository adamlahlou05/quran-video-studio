import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/models/models.dart';
import 'package:quran_video_studio/core/services/subtitle_builder.dart';

void main() {
  const verses = [
    Verse(
      verseKey: '1:1',
      number: 1,
      arabic: 'بِسْمِ اللَّهِ',
      translation: 'Au nom de Dieu {note}',
    ),
    Verse(verseKey: '1:2', number: 2, arabic: 'الْحَمْدُ لِلَّهِ', translation: ''),
  ];
  const audios = [
    VerseAudio(verseKey: '1:1', localPath: '/a.mp3', durationMs: 1500),
    VerseAudio(verseKey: '1:2', localPath: '/b.mp3', durationMs: 2500),
  ];

  String build({StyleSettings style = const StyleSettings()}) =>
      SubtitleBuilder.buildAss(
        verses: verses,
        audios: audios,
        style: style,
        yFraction: 0.5,
      );

  test('les timings s\'enchaînent exactement sur les durées FFprobe', () {
    final ass = build();
    expect(ass, contains('Dialogue: 0,0:00:00.00,0:00:01.50,Arabic'));
    expect(ass, contains('Dialogue: 0,0:00:01.50,0:00:04.00,Arabic'));
  });

  test('les accolades du texte sont neutralisées (balises ASS)', () {
    final ass = build();
    expect(ass, contains('(note)'));
    expect(ass, isNot(contains('{note}')));
  });

  test('la traduction est incluse par défaut, omise si « Aucune »', () {
    expect(build(), contains('Au nom de Dieu'));
    final sansTraduction = build(
      style: const StyleSettings(translation: TranslationLang.none),
    );
    expect(sansTraduction, isNot(contains('Au nom de Dieu')));
  });

  test('résolution et position du script', () {
    final ass = build();
    expect(ass, contains('PlayResX: 1080'));
    expect(ass, contains('PlayResY: 1920'));
    expect(ass, contains('\\pos(540,960)')); // yFraction 0.5 → centre
  });
}
