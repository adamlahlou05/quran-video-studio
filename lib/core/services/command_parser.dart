import 'dart:math';

import '../data/reciter_catalog.dart';
import '../models/models.dart';

/// Résultat de l'analyse d'une instruction libre (« Mishary Alafasy —
/// Al-Baqarah — 42-60 »). Chaque champ est optionnel ; les alternatives
/// listent les correspondances presque aussi plausibles (ambiguïté →
/// l'utilisateur confirme, l'app n'invente jamais en silence).
class CommandResult {
  final Reciter? reciter;
  final Chapter? chapter;
  final int? from;
  final int? to;
  final List<Reciter> reciterAlternatives;
  final List<Chapter> chapterAlternatives;

  const CommandResult({
    this.reciter,
    this.chapter,
    this.from,
    this.to,
    this.reciterAlternatives = const [],
    this.chapterAlternatives = const [],
  });

  bool get hasAnything => reciter != null || chapter != null || from != null;
}

/// Analyse locale, tolérante (accents, harakat, tirets, variantes de
/// translittération, petites fautes de frappe via distance d'édition ≤ 1-2).
CommandResult parseCommand(
  String input, {
  required List<Chapter> chapters,
  required List<Reciter> reciters,
}) {
  final norm = normalizeSearchText(input);
  final normNoSpace = norm.replaceAll(' ', '');

  // ── Plage de versets : dernier « a-b », sinon verset unique explicite. ──
  int? from;
  int? to;
  final rangeMatches = RegExp(r'(\d{1,3})\s*(?:-|–|—|\bto\b|\bà\b)\s*(\d{1,3})')
      .allMatches(input)
      .toList();
  if (rangeMatches.isNotEmpty) {
    final m = rangeMatches.last;
    from = int.parse(m.group(1)!);
    to = int.parse(m.group(2)!);
    if (to < from) {
      final tmp = from;
      from = to;
      to = tmp;
    }
  } else {
    final single = RegExp(
            r'(?:versets?|verses?|ayahs?|ayat?|آية|الآية|آيات)\s*:?\s*(\d{1,3})',
            caseSensitive: false)
        .firstMatch(input);
    if (single != null) {
      from = int.parse(single.group(1)!);
      to = from;
    }
  }

  // ── Sourate : numéro explicite prioritaire, sinon nom (multi-champs). ──
  Chapter? chapter;
  var chapterAlternatives = <Chapter>[];
  final surahNum = RegExp(
          r'(?:sourate|surah|surat|سورة)\s*(?:n[°o]\s*)?:?\s*(\d{1,3})',
          caseSensitive: false)
      .firstMatch(input);
  if (surahNum != null) {
    final id = int.parse(surahNum.group(1)!);
    for (final c in chapters) {
      if (c.id == id) chapter = c;
    }
  }
  if (chapter == null) {
    final inputWordsForChapter =
        norm.split(' ').where((w) => w.length >= 4 && !_isNumeric(w));
    var bestScore = 0;
    final scored = <(Chapter, int)>[];
    for (final c in chapters) {
      var score = max(
        _containScore(norm, normNoSpace, c.nameSimple),
        max(_containScore(norm, normNoSpace, c.translatedName),
            _containScore(norm, normNoSpace, c.nameArabic)),
      );
      // Mot partiel : « fatiha » doit trouver « Al-Fatihah ».
      for (final w in inputWordsForChapter) {
        for (final cand in [c.nameSimple, c.translatedName, c.nameArabic]) {
          final candNorm = normalizeSearchText(cand);
          if (candNorm.contains(w) ||
              candNorm.replaceAll(' ', '').contains(w)) {
            score = max(score, w.length);
          }
        }
      }
      if (score > 0) scored.add((c, score));
      bestScore = max(bestScore, score);
    }
    if (bestScore > 0) {
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      chapter = scored.first.$1;
      chapterAlternatives = [
        for (final s in scored.skip(1))
          if (s.$2 >= bestScore - 2) s.$1,
      ].take(3).toList();
    }
  }

  // ── Récitateur : nom complet, mots significatifs, arabe, fuzzy léger. ──
  Reciter? reciter;
  var reciterAlternatives = <Reciter>[];
  final inputWords =
      norm.split(' ').where((w) => w.length >= 3 && !_isNumeric(w)).toList();
  var bestScore = 0;
  final scored = <(Reciter, int)>[];
  for (final r in reciters) {
    var score = max(
      _containScore(norm, normNoSpace, r.name) * 3,
      _containScore(norm, normNoSpace, r.arabicName) * 3,
    );
    // Mots significatifs des noms latin ET arabe (« السديس » seul suffit).
    final nameWords = {
      ...normalizeSearchText(r.name).split(' '),
      ...normalizeSearchText(r.arabicName).split(' '),
    }.where((w) => w.length >= 4);
    for (final word in nameWords) {
      for (final iw in inputWords) {
        if (iw == word || iw.contains(word) || word.contains(iw)) {
          score += word.length * 2;
        } else if (_levenshtein(iw, word) <= (word.length >= 6 ? 2 : 1)) {
          score += word.length;
        }
      }
    }
    // Style explicite (mujawwad / muallim) : petit bonus discriminant.
    final styleNorm = normalizeSearchText(r.style);
    if (styleNorm.isNotEmpty && norm.contains(styleNorm)) score += 6;
    if (score > 0) scored.add((r, score));
    bestScore = max(bestScore, score);
  }
  if (bestScore > 0) {
    // À score égal, l'ordre du catalogue tranche (variante de base d'abord) :
    // scored est construit dans cet ordre, on prend le premier au meilleur
    // score — déterministe.
    reciter = scored.firstWhere((s) => s.$2 == bestScore).$1;
    final chosen = reciter;
    reciterAlternatives = [
      for (final s in scored)
        if (s.$1.id != chosen.id && s.$2 >= bestScore * 0.7) s.$1,
    ].take(3).toList();
  }

  return CommandResult(
    reciter: reciter,
    chapter: chapter,
    from: from,
    to: to,
    reciterAlternatives: reciterAlternatives,
    chapterAlternatives: chapterAlternatives,
  );
}

int _containScore(String norm, String normNoSpace, String candidate) {
  final c = normalizeSearchText(candidate);
  if (c.isEmpty) return 0;
  if (norm.contains(c)) return c.length;
  final cNoSpace = c.replaceAll(' ', '');
  if (cNoSpace.length >= 4 && normNoSpace.contains(cNoSpace)) {
    return cNoSpace.length;
  }
  return 0;
}

bool _isNumeric(String s) => int.tryParse(s) != null;

/// Distance d'édition (petits tableaux : noms courts uniquement).
int _levenshtein(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 99;
  final m = a.length, n = b.length;
  var prev = List<int>.generate(n + 1, (j) => j);
  for (var i = 1; i <= m; i++) {
    final cur = List<int>.filled(n + 1, 0)..[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[n];
}
