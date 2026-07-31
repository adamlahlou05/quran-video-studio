# Quran Video Studio

Application Android (Flutter) de génération de vidéos verticales **9:16** de
récitation coranique : audio du récitateur, texte arabe (uthmani, avec
harakat) et traduction **synchronisés verset par verset**, incrustés sur une
vidéo d'arrière-plan choisie dans la galerie.

Aucun environnement local n'est nécessaire : le dépôt est compilé par
**GitHub Actions**, qui publie les APK dans les *Artifacts* de chaque build.

## Architecture

| Brique | Choix | Pourquoi |
|---|---|---|
| UI | Flutter (Material 3, écran unique) | Rendu RTL/arabe natif, un seul code, CI simple |
| État | Riverpod (`Notifier` + état immuable) | Éditeur réactif : tout changement met l'aperçu à jour |
| Vidéo | `ffmpeg_kit_flutter_new` (fork maintenu de FFmpegKit) | Exécution asynchrone hors UI thread, libass + x264 inclus |
| Incrustation | Sous-titres **ASS** rendus par libass | fribidi + harfbuzz : ligatures et harakat corrects (drawtext casserait l'arabe) |
| Synchronisation | Audios **par verset** concaténés, durées mesurées par FFprobe | Le timing de chaque verset découle de la durée réelle de son mp3 : sync exacte par construction, pour tous les récitateurs |
| Audio | Catalogue **statique vérifié** de 36 récitateurs — everyayah.com (primaire) + cdn.islamic.network (secours) | Chaque source est validée par requêtes HTTP réelles avant inclusion : plus de récitateurs affichés dont les fichiers renvoient 404 |
| Données texte | API publique quran.com v4 | Sourates, texte uthmani, traductions (FR Hamidullah #31, EN Saheeh International #20) |
| Galerie | `gal` | Enregistrement du .mp4 compatible Android 10 → 14+ |

### Pipeline de génération (onglet « Générer »)

1. mp3 des versets déjà en cache (téléchargés au choix du récitateur, avec
   retry, timeout et bascule automatique sur le CDN de secours) ;
2. fichier *concat* FFmpeg + fichier `.ass` généré à la volée (timings cumulés,
   style/couleur/opacité/position du drag & drop) ;
3. `ffmpeg -stream_loop -1 -i fond.mp4 -f concat -i liste.txt -filter_complex
   "scale/crop 1080×1920, subtitles=….ass, fade=t=out:color=noir|blanc"
   -map [v] -map 1:a -t <durée récitation> -c:v libx264 -c:a aac` ;
4. progression temps réel (callback statistiques FFmpegKit), annulable ;
5. sauvegarde dans l'album **Quran Video Studio** de la galerie.

**Règles de durée** : l'audio de la récitation est la source de vérité.
Vidéo plus longue → coupée à la fin de la récitation ; plus courte → bouclée
automatiquement (`-stream_loop -1`) ; dans les deux cas, fondu final (noir ou
blanc, au choix dans l'onglet Générer). La piste audio éventuelle de la vidéo
importée n'est **jamais** mappée dans le fichier final, et l'aperçu la coupe
aussi (`setVolume(0)` + `mixWithOthers`).

## CI/CD

`.github/workflows/build-apk.yml`, déclenché à chaque push sur `main` (ou à la
main via *Run workflow*) :

- Java 17 + Flutter 3.35.4 épinglé ;
- téléchargement des polices **Amiri** et **Scheherazade New** (SIL OFL) —
  binaires absents du repo ;
- `flutter create . --platforms=android` régénère le scaffold Android
  (y compris le `gradle-wrapper.jar`, impossible à versionner en texte) ;
- patch : `minSdk 24` (requis par FFmpegKit), manifeste avec permission
  INTERNET + stockage rétro-compatible, label de l'app ;
- `flutter analyze` + `flutter test` (catalogue, timings ASS, filtre FFmpeg) —
  le build échoue si l'analyse ou un test échoue ;
- `flutter build apk --release --split-per-abi`, signé avec la clé debug
  auto-générée → installable sur Android 13/14 ;
- APK renommés `QuranVideoStudio-v<version>-<abi>.apk`, publiés en artifact
  **et** en Release GitHub (téléchargeables sans compte).

**Quel APK installer ?** `QuranVideoStudio-v…-arm64-v8a.apk` pour tout
téléphone récent (2017+). `armeabi-v7a` pour les très vieux appareils,
`x86_64` pour les émulateurs.

## Licences et crédits

- Contenu coranique : [quran.com API](https://api-docs.quran.foundation/) (publique et gratuite).
- Polices Amiri et Scheherazade New : SIL Open Font License.
- FFmpeg complet (dont x264) : l'application embarque des composants **GPL v3**
  — distribution du binaire soumise à la GPL (projet pédagogique, sources ouvertes).
