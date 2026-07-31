import '../models/models.dart';

/// Catalogue statique de récitateurs, chacun vérifié par requêtes HTTP réelles
/// (premier ET dernier verset du Coran) avant inclusion — voir README.
///
/// Source primaire : everyayah.com (un mp3 par verset, nommage SSSAAA.mp3).
/// Source de secours : cdn.islamic.network (un mp3 par numéro d'ayah global),
/// utilisée automatiquement si everyayah est injoignable pour un fichier.
///
/// Un catalogue statique élimine la cause des « HTTP 404 » de la v1 : la liste
/// affichée provenait d'une API dont le CDN n'hébergeait pas les fichiers de
/// tous les récitateurs listés. Ici, aucun récitateur n'apparaît dans l'UI
/// sans source audio vérifiée.

/// Nombre de versets de chacune des 114 sourates (canon Hafs, total 6236).
/// Sert à calculer le numéro d'ayah global requis par cdn.islamic.network.
const List<int> kVerseCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, //
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135, //
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, //
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85, //
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, //
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13, //
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, //
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, //
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, //
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11, //
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, //
  5, 4, 5, 6,
];

/// Numéro d'ayah global (1..6236) d'un verset, ex. (114, 1) → 6231.
int globalAyahNumber(int chapterId, int verseNumber) {
  var offset = 0;
  for (var i = 0; i < chapterId - 1; i++) {
    offset += kVerseCounts[i];
  }
  return offset + verseNumber;
}

/// URLs candidates pour l'audio d'un verset : primaire everyayah, puis
/// secours islamic.network si le récitateur y possède une édition.
List<String> audioUrlCandidates(
  Reciter reciter,
  int chapterId,
  int verseNumber,
) {
  final sss = chapterId.toString().padLeft(3, '0');
  final aaa = verseNumber.toString().padLeft(3, '0');
  final urls = <String>[
    'https://everyayah.com/data/${reciter.everyayahFolder}/$sss$aaa.mp3',
  ];
  final edition = reciter.fallbackEdition;
  if (edition != null) {
    final global = globalAyahNumber(chapterId, verseNumber);
    urls.add('https://cdn.islamic.network/quran/audio/'
        '${reciter.fallbackBitrate}/$edition/$global.mp3');
  }
  return urls;
}

/// Récitateurs disponibles, du plus populaire au moins connu. Chaque dossier
/// everyayah et chaque édition islamic.network de cette liste a été validé.
const List<Reciter> kReciters = [
  Reciter(
    id: 'alafasy',
    name: 'Mishary Rashid Alafasy',
    everyayahFolder: 'Alafasy_128kbps',
    fallbackEdition: 'ar.alafasy',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'sudais',
    name: 'Abdul Rahman As-Sudais',
    everyayahFolder: 'Abdurrahmaan_As-Sudais_192kbps',
    fallbackEdition: 'ar.abdurrahmaansudais',
    fallbackBitrate: 192,
  ),
  Reciter(
    id: 'dossari',
    name: 'Yasser Al-Dossari',
    everyayahFolder: 'Yasser_Ad-Dussary_128kbps',
  ),
  Reciter(
    id: 'ghamdi',
    name: 'Saad Al-Ghamdi',
    everyayahFolder: 'Ghamadi_40kbps',
  ),
  Reciter(
    id: 'abdul_basit',
    name: 'Abdul Basit Abdus-Samad',
    style: 'Murattal',
    everyayahFolder: 'Abdul_Basit_Murattal_192kbps',
    fallbackEdition: 'ar.abdulsamad',
    fallbackBitrate: 64,
  ),
  Reciter(
    id: 'abdul_basit_mujawwad',
    name: 'Abdul Basit Abdus-Samad',
    style: 'Mujawwad',
    everyayahFolder: 'Abdul_Basit_Mujawwad_128kbps',
  ),
  Reciter(
    id: 'shuraim',
    name: 'Saud Ash-Shuraim',
    everyayahFolder: 'Saood_ash-Shuraym_128kbps',
    fallbackEdition: 'ar.saoodshuraym',
    fallbackBitrate: 64,
  ),
  Reciter(
    id: 'shatri',
    name: 'Abu Bakr Ash-Shatri',
    everyayahFolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
    fallbackEdition: 'ar.shaatree',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'muaiqly',
    name: 'Maher Al-Muaiqly',
    everyayahFolder: 'MaherAlMuaiqly128kbps',
    fallbackEdition: 'ar.mahermuaiqly',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'husary',
    name: 'Mahmoud Khalil Al-Husary',
    everyayahFolder: 'Husary_128kbps',
    fallbackEdition: 'ar.husary',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'husary_muallim',
    name: 'Mahmoud Khalil Al-Husary',
    style: 'Muallim',
    everyayahFolder: 'Husary_Muallim_128kbps',
  ),
  Reciter(
    id: 'minshawi',
    name: 'Mohamed Siddiq El-Minshawi',
    style: 'Murattal',
    everyayahFolder: 'Minshawy_Murattal_128kbps',
    fallbackEdition: 'ar.minshawi',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'minshawi_mujawwad',
    name: 'Mohamed Siddiq El-Minshawi',
    style: 'Mujawwad',
    everyayahFolder: 'Minshawy_Mujawwad_192kbps',
  ),
  Reciter(
    id: 'rifai',
    name: 'Hani Ar-Rifai',
    everyayahFolder: 'Hani_Rifai_192kbps',
    fallbackEdition: 'ar.hanirifai',
    fallbackBitrate: 192,
  ),
  Reciter(
    id: 'hudhaify',
    name: 'Ali Al-Hudhaify',
    everyayahFolder: 'Hudhaify_128kbps',
    fallbackEdition: 'ar.hudhaify',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'ajmi',
    name: 'Ahmed Al-Ajmi',
    everyayahFolder: 'ahmed_ibn_ali_al_ajamy_128kbps',
    fallbackEdition: 'ar.ahmedajamy',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'ayyub',
    name: 'Muhammad Ayyub',
    everyayahFolder: 'Muhammad_Ayyoub_128kbps',
    fallbackEdition: 'ar.muhammadayyoub',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'jibreel',
    name: 'Muhammad Jibreel',
    everyayahFolder: 'Muhammad_Jibreel_128kbps',
    fallbackEdition: 'ar.muhammadjibreel',
    fallbackBitrate: 128,
  ),
  Reciter(
    id: 'tablawi',
    name: 'Mohammad Al-Tablawi',
    everyayahFolder: 'Mohammad_al_Tablaway_128kbps',
  ),
  Reciter(
    id: 'basfar',
    name: 'Abdullah Basfar',
    everyayahFolder: 'Abdullah_Basfar_192kbps',
    fallbackEdition: 'ar.abdullahbasfar',
    fallbackBitrate: 192,
  ),
  Reciter(
    id: 'juhani',
    name: 'Abdullah Awad Al-Juhani',
    everyayahFolder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
  ),
  Reciter(
    id: 'ali_jaber',
    name: 'Ali Jaber',
    everyayahFolder: 'Ali_Jaber_64kbps',
  ),
  Reciter(
    id: 'fares_abbad',
    name: 'Fares Abbad',
    everyayahFolder: 'Fares_Abbad_64kbps',
  ),
  Reciter(
    id: 'qatami',
    name: 'Nasser Al-Qatami',
    everyayahFolder: 'Nasser_Alqatami_128kbps',
  ),
  Reciter(
    id: 'budair',
    name: 'Salah Al-Budair',
    everyayahFolder: 'Salah_Al_Budair_128kbps',
  ),
  Reciter(
    id: 'qasim',
    name: 'AbdulMuhsin Al-Qasim',
    everyayahFolder: 'Muhsin_Al_Qasim_192kbps',
  ),
  Reciter(
    id: 'matroud',
    name: 'Abdullah Al-Matroud',
    everyayahFolder: 'Abdullah_Matroud_128kbps',
  ),
  Reciter(
    id: 'sahl_yassin',
    name: 'Sahl Yassin',
    everyayahFolder: 'Sahl_Yassin_128kbps',
  ),
  Reciter(
    id: 'aziz_alili',
    name: 'Aziz Alili',
    everyayahFolder: 'Aziz_Alili_128kbps',
  ),
  Reciter(
    id: 'alaqmi',
    name: 'Akram Al-Alaqmi',
    everyayahFolder: 'Akram_AlAlaqimy_128kbps',
  ),
  Reciter(
    id: 'suesy',
    name: 'Ali Hajjaj Al-Suesy',
    everyayahFolder: 'Ali_Hajjaj_AlSuesy_128kbps',
  ),
  Reciter(
    id: 'tunaiji',
    name: 'Khalifa Al-Tunaiji',
    everyayahFolder: 'khalefa_al_tunaiji_64kbps',
  ),
  Reciter(
    id: 'banna',
    name: 'Mahmoud Ali Al-Banna',
    everyayahFolder: 'mahmoud_ali_al_banna_32kbps',
  ),
  Reciter(
    id: 'akhdar',
    name: 'Ibrahim Al-Akhdar',
    everyayahFolder: 'Ibrahim_Akhdar_32kbps',
  ),
  Reciter(
    id: 'swaid',
    name: 'Ayman Swaid',
    everyayahFolder: 'Ayman_Sowaid_64kbps',
  ),
  Reciter(
    id: 'salamah',
    name: 'Yaser Salamah',
    everyayahFolder: 'Yaser_Salamah_128kbps',
  ),
];
