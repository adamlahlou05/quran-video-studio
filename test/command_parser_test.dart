import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/data/reciter_catalog.dart';
import 'package:quran_video_studio/core/models/models.dart';
import 'package:quran_video_studio/core/services/command_parser.dart';

Chapter _c(int id, String name, String arabic, int verses) => Chapter(
      id: id,
      nameSimple: name,
      nameArabic: arabic,
      translatedName: '',
      versesCount: verses,
    );

final _chapters = [
  _c(1, 'Al-Fatihah', 'الفاتحة', 7),
  _c(2, 'Al-Baqarah', 'البقرة', 286),
  _c(36, 'Ya-Sin', 'يس', 83),
];

CommandResult _parse(String input) =>
    parseCommand(input, chapters: _chapters, reciters: kReciters);

void main() {
  test('instruction structurée complète', () {
    final r = _parse(
        'Récitateur : Mishary Alafasy, Sourate : Al-Baqarah, Versets : 42-60');
    expect(r.reciter?.id, 'alafasy');
    expect(r.chapter?.id, 2);
    expect(r.from, 42);
    expect(r.to, 60);
  });

  test('format libre avec tirets', () {
    final r = _parse('yasser dossari — ya-sin — 1-12');
    expect(r.reciter?.id, 'dossari');
    expect(r.chapter?.id, 36);
    expect((r.from, r.to), (1, 12));
  });

  test('numéro de sourate + verset unique', () {
    final r = _parse('sourate 2 verset 255');
    expect(r.chapter?.id, 2);
    expect((r.from, r.to), (255, 255));
  });

  test('entièrement en arabe', () {
    final r = _parse('السديس البقرة 1-5');
    expect(r.reciter?.id, 'sudais');
    expect(r.chapter?.id, 2);
    expect((r.from, r.to), (1, 5));
  });

  test('petite faute de frappe et nom de sourate partiel', () {
    final r = _parse('alafassy fatiha 1-3');
    expect(r.reciter?.id, 'alafasy');
    expect(r.chapter?.id, 1);
  });

  test('nom ambigu → variante de base + alternatives proposées', () {
    final r = _parse('abdul basit al-fatihah 1-7');
    expect(r.reciter?.id, 'abdul_basit');
    expect(r.reciterAlternatives.map((a) => a.id),
        contains('abdul_basit_mujawwad'));
  });

  test('style explicite : mujawwad sélectionné directement', () {
    final r = _parse('abdul basit mujawwad al-fatihah 1-7');
    expect(r.reciter?.id, 'abdul_basit_mujawwad');
  });

  test('plage inversée corrigée, texte vide sans résultat', () {
    expect((_parse('alafasy fatiha 7-3').from, _parse('x').hasAnything),
        (3, false));
  });
}
