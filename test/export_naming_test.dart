import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/models/models.dart';
import 'package:quran_video_studio/core/services/export_naming.dart';

const _alafasy = Reciter(
  id: 'alafasy',
  name: 'Mishary Rashid Alafasy',
  everyayahFolder: 'Alafasy_128kbps',
);
const _fatiha = Chapter(
  id: 1,
  nameSimple: 'Al-Fatihah',
  nameArabic: 'الفاتحة',
  translatedName: "L'ouverture",
  versesCount: 7,
);

void main() {
  group('slugify', () {
    test('espaces → tirets, ASCII sûr pour tous les systèmes de fichiers',
        () {
      expect(slugify('Mishary Rashid Alafasy'), 'Mishary-Rashid-Alafasy');
      expect(slugify("Al-Mu'minun"), 'Al-Muminun');
      expect(slugify('Récitateur spécial'), 'Recitateur-special');
    });

    test('caractères non transcodables → repli', () {
      expect(slugify('العفاسي'), 'Video');
      expect(slugify('   ', fallback: 'Sourate1'), 'Sourate1');
    });

    test('tirets multiples et bords nettoyés', () {
      expect(slugify('--A  B--'), 'A-B');
    });
  });

  group('buildVideoFileName', () {
    test('format 001_Recitateur_Sourate_v1-7.mp4', () {
      expect(
        buildVideoFileName(
          number: 1,
          reciter: _alafasy,
          chapter: _fatiha,
          ayahFrom: 1,
          ayahTo: 7,
        ),
        '001_Mishary-Rashid-Alafasy_Al-Fatihah_v1-7.mp4',
      );
    });

    test('verset unique et numéros à trois chiffres', () {
      final name = buildVideoFileName(
        number: 42,
        reciter: _alafasy,
        chapter: _fatiha,
        ayahFrom: 5,
        ayahTo: 5,
      );
      expect(name, startsWith('042_'));
      expect(name, contains('_v5.mp4'));
    });

    test('au-delà de 999, le numéro s’allonge sans casser le tri', () {
      expect(
        buildVideoFileName(
          number: 1000,
          reciter: _alafasy,
          chapter: _fatiha,
          ayahFrom: 1,
          ayahTo: 2,
        ),
        startsWith('1000_'),
      );
    });

    test('nom compatible MediaStore : ASCII, sans espace ni réservé', () {
      final name = buildVideoFileName(
        number: 7,
        reciter: _alafasy,
        chapter: _fatiha,
        ayahFrom: 1,
        ayahTo: 3,
      );
      expect(RegExp(r'^[A-Za-z0-9._-]+\.mp4$').hasMatch(name), isTrue);
    });
  });

  group('buildShareDescription', () {
    test('réciteur — sourate — versets + hashtags', () {
      final text = buildShareDescription(
        reciter: _alafasy,
        chapter: _fatiha,
        ayahFrom: 1,
        ayahTo: 7,
        hashtags: '#Quran #Islam',
      );
      expect(text,
          'Mishary Rashid Alafasy — Sourate Al-Fatihah — Versets 1 à 7'
          '\n\n#Quran #Islam');
    });

    test('verset unique, hashtags vides → pas de bloc hashtags', () {
      final text = buildShareDescription(
        reciter: _alafasy,
        chapter: _fatiha,
        ayahFrom: 3,
        ayahTo: 3,
        hashtags: '   ',
      );
      expect(text, contains('Verset 3'));
      expect(text, isNot(contains('\n\n')));
    });
  });
}
