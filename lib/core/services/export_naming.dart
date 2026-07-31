import '../models/models.dart';

/// Hashtags proposés par défaut sous la description de partage.
const String kDefaultHashtags =
    '#Quran #QuranRecitation #Islam #Coran #Tilawa #QuranVideo';

/// Nom de fichier lisible et sûr pour tous les systèmes (MediaStore, galerie,
/// Google Photos, partage, explorateurs) : ASCII, ni espace ni caractère
/// réservé, extension .mp4. Ex. : 001_Mishary-Rashid-Alafasy_Al-Fatihah_v1-7.mp4
String buildVideoFileName({
  required int number,
  required Reciter reciter,
  required Chapter chapter,
  required int ayahFrom,
  required int ayahTo,
}) {
  final index = number.toString().padLeft(3, '0');
  final verses = ayahFrom == ayahTo ? 'v$ayahFrom' : 'v$ayahFrom-$ayahTo';
  return '${index}_${slugify(reciter.name)}_${slugify(chapter.nameSimple)}'
      '_$verses.mp4';
}

/// Description prête à coller sur TikTok/Instagram/YouTube. Un hashtag
/// dérivé du nom du récitateur est ajouté automatiquement s'il n'est pas
/// déjà présent dans les hashtags de l'utilisateur.
String buildShareDescription({
  required Reciter reciter,
  required Chapter chapter,
  required int ayahFrom,
  required int ayahTo,
  required String hashtags,
}) {
  final verses = ayahFrom == ayahTo
      ? 'Verset $ayahFrom'
      : 'Versets $ayahFrom à $ayahTo';
  final buffer = StringBuffer(
      '${reciter.displayName} — Sourate ${chapter.nameSimple} — $verses');
  var tags = hashtags.trim();
  final reciterTag = slugify(reciter.name).replaceAll('-', '');
  if (reciterTag != 'Video' &&
      !tags.toLowerCase().contains(reciterTag.toLowerCase())) {
    tags = tags.isEmpty ? '#$reciterTag' : '$tags #$reciterTag';
  }
  if (tags.isNotEmpty) {
    buffer.write('\n\n$tags');
  }
  return buffer.toString();
}

/// Nom de base (sans extension) d'une image-citation,
/// ex. : 001_Mishary-Rashid-Alafasy_Al-Fatihah_v3
String buildImageFileName({
  required int number,
  required Reciter reciter,
  required Chapter chapter,
  required int verseNumber,
}) {
  final index = number.toString().padLeft(3, '0');
  return '${index}_${slugify(reciter.name)}_${slugify(chapter.nameSimple)}'
      '_v$verseNumber';
}

/// Normalise un libellé en segment de nom de fichier : accents aplatis,
/// espaces → tirets, tout caractère hors [A-Za-z0-9-] supprimé.
String slugify(String input, {String fallback = 'Video'}) {
  var t = input.trim();
  const accents = {
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'É': 'E', 'È': 'E',
    'à': 'a', 'â': 'a', 'ä': 'a', 'À': 'A', 'Â': 'A',
    'î': 'i', 'ï': 'i', 'Î': 'I',
    'ô': 'o', 'ö': 'o', 'Ô': 'O',
    'û': 'u', 'ù': 'u', 'ü': 'u', 'Û': 'U',
    'ç': 'c', 'Ç': 'C',
  };
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  t = t
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return t.isEmpty ? fallback : t;
}
