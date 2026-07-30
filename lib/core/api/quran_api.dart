import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Client de l'API publique quran.com (v4).
///
/// - Métadonnées : sourates, récitateurs.
/// - Contenu : texte uthmani + traduction, paginé par 50 versets.
/// - Audio : un fichier mp3 par verset, servi par le CDN verses.quran.com.
class QuranApi {
  static const String _base = 'https://api.quran.com/api/v4';
  static const String _audioCdn = 'https://verses.quran.com/';

  /// Récitateurs mis en avant dans l'UI, dans cet ordre.
  /// 7 = Alafasy, 3 = As-Sudais, 2/1 = AbdulBaset, 4 = Ash-Shatri,
  /// 6 = Al-Husary, 9 = Al-Minshawi, 10 = Ash-Shuraym, 5 = Ar-Rifai.
  static const List<int> _featuredReciters = [7, 3, 2, 1, 4, 6, 9, 10, 5];

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _getJson(String pathAndQuery) async {
    final response = await _client.get(
      Uri.parse('$_base$pathAndQuery'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('API quran.com : HTTP ${response.statusCode}');
    }
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Chapter>> fetchChapters({String language = 'fr'}) async {
    final data = await _getJson('/chapters?language=$language');
    return (data['chapters'] as List)
        .map((e) => Chapter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Reciter>> fetchReciters() async {
    final data = await _getJson('/resources/recitations?language=en');
    final all = (data['recitations'] as List)
        .map((e) => Reciter.fromJson(e as Map<String, dynamic>))
        .toList();
    all.sort((a, b) {
      final ia = _featuredReciters.indexOf(a.id);
      final ib = _featuredReciters.indexOf(b.id);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return a.name.compareTo(b.name);
    });
    return all;
  }

  /// Tous les versets d'une sourate, avec traduction si [translationId] est
  /// fourni. Les notes de bas de page HTML des traductions sont supprimées.
  Future<List<Verse>> fetchVerses({
    required int chapterId,
    int? translationId,
  }) async {
    final verses = <Verse>[];
    final translationParam =
        translationId == null ? '' : '&translations=$translationId';
    int? page = 1;
    while (page != null) {
      final data = await _getJson(
        '/verses/by_chapter/$chapterId'
        '?words=false&fields=text_uthmani$translationParam'
        '&per_page=50&page=$page',
      );
      for (final raw in data['verses'] as List) {
        final v = raw as Map<String, dynamic>;
        var translation = '';
        final translations = v['translations'] as List?;
        if (translations != null && translations.isNotEmpty) {
          translation = _stripHtml(
            (translations.first as Map<String, dynamic>)['text'] as String? ??
                '',
          );
        }
        verses.add(Verse(
          verseKey: v['verse_key'] as String,
          number: v['verse_number'] as int,
          arabic: (v['text_uthmani'] as String? ?? '').trim(),
          translation: translation,
        ));
      }
      page = (data['pagination'] as Map<String, dynamic>?)?['next_page'] as int?;
    }
    verses.sort((a, b) => a.number.compareTo(b.number));
    return verses;
  }

  /// URLs audio absolues, indexées par verse_key ("2:255" → https://…mp3).
  Future<Map<String, String>> fetchAudioUrls({
    required int reciterId,
    required int chapterId,
  }) async {
    final urls = <String, String>{};
    int? page = 1;
    while (page != null) {
      final data = await _getJson(
        '/recitations/$reciterId/by_chapter/$chapterId?per_page=50&page=$page',
      );
      for (final raw in data['audio_files'] as List) {
        final f = raw as Map<String, dynamic>;
        final url = f['url'] as String? ?? '';
        if (url.isEmpty) continue;
        urls[f['verse_key'] as String] =
            url.startsWith('http') ? url : '$_audioCdn$url';
      }
      page = (data['pagination'] as Map<String, dynamic>?)?['next_page'] as int?;
    }
    return urls;
  }

  static String _stripHtml(String input) =>
      input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
