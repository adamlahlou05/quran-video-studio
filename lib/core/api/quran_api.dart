import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Client de l'API publique quran.com (v4) — texte uniquement.
///
/// - Métadonnées : sourates.
/// - Contenu : texte uthmani + traduction, paginé par 50 versets.
///
/// L'audio ne passe plus par cette API : les récitateurs viennent du
/// catalogue statique vérifié (core/data/reciter_catalog.dart).
class QuranApi {
  static const String _base = 'https://api.quran.com/api/v4';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _getJson(String pathAndQuery) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse('$_base$pathAndQuery'),
        headers: const {'Accept': 'application/json'},
      ).timeout(_timeout);
    } on TimeoutException {
      throw Exception('serveur quran.com trop lent (délai dépassé)');
    }
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

  static String _stripHtml(String input) =>
      input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
