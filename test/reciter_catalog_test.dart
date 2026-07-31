import 'package:flutter_test/flutter_test.dart';
import 'package:quran_video_studio/core/data/reciter_catalog.dart';
import 'package:quran_video_studio/core/models/models.dart';

void main() {
  group('kVerseCounts', () {
    test('114 sourates, 6236 versets au total (canon Hafs)', () {
      expect(kVerseCounts.length, 114);
      expect(kVerseCounts.reduce((a, b) => a + b), 6236);
    });

    test('valeurs connues', () {
      expect(kVerseCounts[0], 7); // Al-Fatiha
      expect(kVerseCounts[1], 286); // Al-Baqara
      expect(kVerseCounts[35], 83); // Ya-Sin
      expect(kVerseCounts[111], 4); // Al-Ikhlas
      expect(kVerseCounts[113], 6); // An-Nas
    });
  });

  group('globalAyahNumber', () {
    test('bornes et jalons', () {
      expect(globalAyahNumber(1, 1), 1);
      expect(globalAyahNumber(1, 7), 7);
      expect(globalAyahNumber(2, 1), 8);
      expect(globalAyahNumber(2, 255), 262); // Ayat al-Kursi
      expect(globalAyahNumber(114, 1), 6231);
      expect(globalAyahNumber(114, 6), 6236);
    });
  });

  group('catalogue des récitateurs', () {
    test('identifiants et dossiers uniques, champs bien formés', () {
      final ids = kReciters.map((r) => r.id).toSet();
      final folders = kReciters.map((r) => r.everyayahFolder).toSet();
      expect(ids.length, kReciters.length,
          reason: 'chaque récitateur doit avoir un id unique');
      expect(folders.length, kReciters.length,
          reason: 'chaque récitateur doit avoir un dossier unique');
      for (final r in kReciters) {
        expect(r.name, isNotEmpty);
        expect(r.id, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(r.everyayahFolder, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
        if (r.fallbackEdition != null) {
          expect(r.fallbackEdition, matches(RegExp(r'^ar\.[a-z]+$')));
          expect(const [64, 128, 192], contains(r.fallbackBitrate));
        }
      }
    });

    test('le catalogue couvre les récitateurs demandés', () {
      final names = kReciters.map((r) => r.name.toLowerCase()).toList();
      for (final expected in [
        'al-dossari',
        'as-sudais',
        'alafasy',
        'al-ghamdi',
        'abdul basit',
      ]) {
        expect(names.any((n) => n.contains(expected)), isTrue,
            reason: '$expected doit être présent');
      }
    });

    test('URLs générées au bon format (padding SSSAAA + ayah global)', () {
      final alafasy = kReciters.firstWhere((r) => r.id == 'alafasy');
      final urls = audioUrlCandidates(alafasy, 2, 255);
      expect(
          urls.first, 'https://everyayah.com/data/Alafasy_128kbps/002255.mp3');
      expect(urls.last,
          'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3');
    });

    test('récitateur sans fallback → une seule URL candidate', () {
      final dossari = kReciters.firstWhere((r) => r.id == 'dossari');
      expect(audioUrlCandidates(dossari, 1, 1), const [
        'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps/001001.mp3',
      ]);
    });

    test('chaque récitateur a un nom arabe', () {
      for (final r in kReciters) {
        expect(r.arabicName, isNotEmpty, reason: r.id);
      }
    });
  });

  group('recherche des récitateurs', () {
    Reciter byId(String id) => kReciters.firstWhere((r) => r.id == id);

    test('latin partiel, insensible à la casse et aux accents', () {
      expect(reciterMatches(byId('dossari'), 'Yas'), isTrue);
      expect(reciterMatches(byId('sudais'), 'SUDAIS'), isTrue);
      expect(reciterMatches(byId('ghamdi'), 'ghâmdi'), isTrue);
      expect(reciterMatches(byId('alafasy'), 'alafasy'), isTrue);
      expect(reciterMatches(byId('alafasy'), 'sudais'), isFalse);
    });

    test('tirets et espaces ignorés (« aldossari » → Al-Dossari)', () {
      expect(reciterMatches(byId('dossari'), 'aldossari'), isTrue);
      expect(reciterMatches(byId('shatri'), 'ash shatri'), isTrue);
    });

    test('arabe : sous-chaîne du nom, harakat ignorées', () {
      expect(reciterMatches(byId('dossari'), 'ياسر'), isTrue);
      expect(reciterMatches(byId('sudais'), 'السديس'), isTrue);
      expect(reciterMatches(byId('sudais'), 'سديس'), isTrue);
      expect(reciterMatches(byId('alafasy'), 'العفاسي'), isTrue);
      expect(reciterMatches(byId('alafasy'), 'الدوسري'), isFalse);
    });

    test('requête vide : tout le monde correspond', () {
      for (final r in kReciters) {
        expect(reciterMatches(r, ''), isTrue);
        expect(reciterMatches(r, '   '), isTrue);
      }
    });

    test('normalisation : accents, alef, ta marbouta', () {
      expect(normalizeSearchText('Récitâteur'), 'recitateur');
      expect(normalizeSearchText('أحمد'), 'احمد');
      expect(normalizeSearchText('سلامة'), 'سلامه');
    });
  });
}
