import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/image_quote_renderer.dart';
import '../services/settings_service.dart';

/// Langues de l'interface. L'arabe est rendu en vrai RTL (Directionality).
enum AppLanguage {
  fr('Français', 'fr'),
  en('English', 'en'),
  ar('العربية', 'ar');

  final String nativeLabel;
  final String code;
  const AppLanguage(this.nativeLabel, this.code);

  bool get isRtl => this == AppLanguage.ar;
}

/// Langue courante + « déjà choisie ? » (pour le dialogue de premier
/// lancement), persistée dans settings.json.
final appLanguageProvider = NotifierProvider<AppLanguageController,
    ({AppLanguage lang, bool chosen})>(AppLanguageController.new);

class AppLanguageController
    extends Notifier<({AppLanguage lang, bool chosen})> {
  final SettingsService _settings = SettingsService();

  @override
  ({AppLanguage lang, bool chosen}) build() {
    _settings.loadLanguage().then((code) {
      if (code != null) {
        final lang = AppLanguage.values
            .firstWhere((l) => l.code == code, orElse: () => AppLanguage.fr);
        state = (lang: lang, chosen: true);
      }
    });
    return (lang: AppLanguage.fr, chosen: false);
  }

  void setLanguage(AppLanguage lang) {
    state = (lang: lang, chosen: true);
    _settings.saveLanguage(lang.code);
  }
}

/// Chaînes traduites de l'interface courante.
final sProvider =
    Provider<S>((ref) => S(ref.watch(appLanguageProvider).lang));

/// Toutes les chaînes visibles de NUQTA, en FR / EN / AR.
class S {
  final AppLanguage lang;
  const S(this.lang);

  String _(String fr, String en, String ar) => switch (lang) {
        AppLanguage.fr => fr,
        AppLanguage.en => en,
        AppLanguage.ar => ar,
      };

  // ── Onglets ──
  String get tabContent => _('Contenu', 'Content', 'المحتوى');
  String get tabReciter => _('Récitateur', 'Reciter', 'القارئ');
  String get tabStyle => _('Style', 'Style', 'النمط');
  String get tabGenerate => _('Générer', 'Generate', 'إنشاء');

  // ── Canvas / aperçu ──
  String get canvasHint => _(
      'Ajoute un fond (vidéos, images ou couleur)\nvia Contenu → Arrière-plan',
      'Add a background (videos, images or color)\nvia Content → Background',
      'أضف خلفية (فيديو أو صور أو لون)\nمن المحتوى ← الخلفية');
  String audioLoading(int pct) =>
      _('Audio… $pct %', 'Audio… $pct %', 'الصوت… $pct ٪');
  String get textLoading =>
      _('Texte en cours…', 'Loading text…', 'جارٍ تحميل النص…');
  String get playTooltip => _('Lire la prévisualisation',
      'Play the preview', 'تشغيل المعاينة');
  String get pauseTooltip => _('Pause', 'Pause', 'إيقاف مؤقت');
  String videosChip(int n) =>
      _('$n fonds', '$n backgrounds', '$n خلفيات');
  String get playError => _(
      'Lecture impossible — réessaie (fichier audio en cours de validation).',
      'Playback failed — try again (audio file being validated).',
      'تعذّر التشغيل — أعد المحاولة (جارٍ التحقق من الملف الصوتي).');

  // ── Onglet Contenu ──
  String get chooseChapter =>
      _('Choisir une sourate', 'Choose a surah', 'اختر سورة');
  String versesCount(int n) =>
      _('$n versets', '$n verses', '$n آيات');
  String get versesLabel => _('Versets', 'Verses', 'الآيات');
  String ayahRange(int from, int to) =>
      _('Ayah $from → $to', 'Ayah $from → $to', 'الآية $from ← $to');
  String get versesLoading => _('Chargement des versets…',
      'Loading verses…', 'جارٍ تحميل الآيات…');
  String versesLoaded(int n) => _('$n verset(s) chargé(s) ✓',
      '$n verse(s) loaded ✓', 'تم تحميل $n آية ✓');
  String get retry => _('Réessayer', 'Retry', 'إعادة المحاولة');
  String get chaptersError => _(
      'Impossible de charger la liste des sourates.',
      'Could not load the surah list.',
      'تعذّر تحميل قائمة السور.');
  String get searchSurahHint => _('Rechercher une sourate…',
      'Search for a surah…', 'ابحث عن سورة…');
  String get versesUnavailable => _(
      'Versets indisponibles (connexion ?)',
      'Verses unavailable (connection?)',
      'الآيات غير متاحة (تحقق من الاتصال)');

  // ── Commande intelligente ──
  String get commandHint => _(
      'Ex. : Mishary Alafasy — Al-Baqarah — 42-60',
      'E.g.: Mishary Alafasy — Al-Baqarah — 42-60',
      'مثال: مشاري العفاسي — البقرة — 42-60');
  String get commandApply => _('Appliquer', 'Apply', 'تطبيق');
  String get commandNotFound => _(
      'Instruction non comprise — précise le récitateur, la sourate et les versets.',
      'Instruction not understood — specify reciter, surah and verses.',
      'لم تُفهم التعليمات — حدّد القارئ والسورة والآيات.');
  String get commandNeedsChapters => _(
      'Attends le chargement des sourates…',
      'Waiting for the surah list…',
      'انتظر تحميل قائمة السور…');

  // ── Arrière-plans ──
  String get clipsTitle =>
      _("Arrière-plan", 'Background', 'الخلفية');
  String get addClips => _('Ajouter', 'Add', 'إضافة');
  String get clipsEmptyHint => _(
      'Ajoute des vidéos ou des images (lues dans l’ordre, en boucle si '
      'la récitation est plus longue), ou choisis un fond uni ci-dessous.',
      'Add videos or images (played in order, looped if the recitation is '
      'longer), or pick a solid background below.',
      'أضف فيديوهات أو صورًا (تُعرض بالترتيب وتتكرر إذا كانت التلاوة أطول)، '
      'أو اختر لونًا موحّدًا أدناه.');
  String get moveUp => _('Monter', 'Move up', 'أعلى');
  String get moveDown => _('Descendre', 'Move down', 'أسفل');
  String get removeClip => _('Retirer', 'Remove', 'إزالة');
  String get imageBadge => _('Image', 'Image', 'صورة');
  String get transitionBetween => _('Transition entre les fonds',
      'Transition between backgrounds', 'الانتقال بين الخلفيات');
  String totalDurationLabel(String d) =>
      _('Durée totale : $d', 'Total duration: $d', 'المدة الإجمالية: $d');
  String get crossfadeNote => _(' (fondu croisé)', ' (crossfade)',
      ' (تلاشٍ متقاطع)');
  String rejectedFiles(int n) => _(
      '$n fichier(s) ignoré(s) : ni vidéo ni image lisible.',
      '$n file(s) skipped: not a readable video or image.',
      'تم تجاهل $n ملف(ات): ليست فيديو أو صورة قابلة للقراءة.');
  String perImage(String sec) => _('≈ $sec s par image',
      '≈ $sec s per image', '≈ $sec ثانية لكل صورة');
  String get solidTitle => _('Fond uni (sans vidéo ni image)',
      'Solid background (no video/image)', 'خلفية موحّدة (بدون فيديو أو صورة)');
  String get customColor =>
      _('Personnalisée…', 'Custom…', 'مخصّص…');
  String get colorPickerTitle =>
      _('Couleur personnalisée', 'Custom color', 'لون مخصّص');
  String get apply => _('Valider', 'Apply', 'موافق');

  // ── Onglet Récitateur ──
  String searchReciters(int n) => _(
      'Rechercher parmi $n récitateurs (ex. Yasser, سديس)…',
      'Search $n reciters (e.g. Yasser, سديس)…',
      'ابحث بين $n قارئًا (مثل: ياسر، سديس)…');
  String get noReciterMatch => _(
      'Aucun récitateur ne correspond à cette recherche.',
      'No reciter matches this search.',
      'لا يوجد قارئ مطابق لهذا البحث.');
  String audioCaching(int pct) => _(
      'Mise en cache audio… $pct %',
      'Caching audio… $pct %',
      'جارٍ تخزين الصوت… $pct ٪');
  String get audioReadyMsg => _(
      "Audio en cache — prêt pour l'aperçu et la génération",
      'Audio cached — ready for preview and generation',
      'الصوت جاهز — للمعاينة والإنشاء');
  String get selectReciterHint => _(
      'Sélectionne un récitateur pour précharger l’audio.',
      'Select a reciter to preload the audio.',
      'اختر قارئًا لتحميل الصوت مسبقًا.');

  // ── Onglet Style ──
  String get textColorLabel =>
      _('Couleur du texte', 'Text color', 'لون النص');
  String get boxOpacityLabel => _(
      'Opacité du fond derrière le texte',
      'Opacity of the box behind the text',
      'شفافية الخلفية خلف النص');
  String get translationLabel => _('Langue de la traduction',
      'Translation language', 'لغة الترجمة');
  String get fontLabelTitle =>
      _("Police d'écriture arabe", 'Arabic font', 'الخط العربي');
  String get sizeLabel => _('Taille du texte', 'Text size', 'حجم النص');
  String get signatureLabel => _(
      'Signature (filigrane en haut de la vidéo)',
      'Signature (watermark at the top of the video)',
      'التوقيع (علامة مائية أعلى الفيديو)');
  String get signatureHint => _(
      '@toncompte (laisser vide pour désactiver)',
      '@yourhandle (leave empty to disable)',
      '@حسابك (اتركه فارغًا للتعطيل)');
  String fontLabel(ArabicFont font) => switch (font) {
        ArabicFont.amiri => _('Calligraphie classique',
            'Classic calligraphy', 'خط كلاسيكي مزخرف'),
        ArabicFont.scheherazade => _('Claire et lisible',
            'Clear & readable', 'واضح وسهل القراءة'),
      };
  String translationName(TranslationLang t) => switch (t) {
        TranslationLang.none => _('Aucune', 'None', 'بدون'),
        TranslationLang.french => 'Français',
        TranslationLang.english => 'English',
      };

  // ── Onglet Générer ──
  String get noChapterSelected => _('Aucune sourate sélectionnée',
      'No surah selected', 'لم تُختر سورة');
  String chapterSummary(String name, int from, int to) => _(
      'Sourate $name, versets $from à $to',
      'Surah $name, verses $from to $to',
      'سورة $name، الآيات $from إلى $to');
  String get noReciter =>
      _('Aucun récitateur', 'No reciter', 'لا يوجد قارئ');
  String durationEstimated(String d) => _('Durée estimée : $d',
      'Estimated duration: $d', 'المدة المقدّرة: $d');
  String get durationPending => _(
      'Durée estimée : — (audio en préparation)',
      'Estimated duration: — (audio being prepared)',
      'المدة المقدّرة: — (جارٍ تجهيز الصوت)');
  String clipsSummary(int n, String d) => _(
      '$n fond(s), $d au total (1080×1920, recadrage auto)',
      '$n background(s), $d total (1080×1920, auto-crop)',
      '$n خلفية، المجموع $d (1080×1920)');
  String get solidSummary => _('Fond uni (couleur)',
      'Solid color background', 'خلفية بلون موحّد');
  String get noBackground => _('Aucun arrière-plan choisi',
      'No background selected', 'لم تُختر خلفية');
  String get fadeLabel => _('Fondu de fin', 'Ending fade', 'تلاشي النهاية');
  String get qualityLabel =>
      _("Qualité d'export", 'Export quality', 'جودة التصدير');
  String get hashtagsLabel => _(
      'Hashtags de la description de partage',
      'Hashtags for the share description',
      'وسوم وصف المشاركة');
  String get generateBtn =>
      _('Générer la vidéo', 'Generate the video', 'إنشاء الفيديو');
  String get quoteBtn =>
      _('Image-citation (PNG)', 'Quote image (PNG)', 'صورة اقتباس (PNG)');
  String get cancel => _('Annuler', 'Cancel', 'إلغاء');
  String get doneAlbum => _('Album « NUQTA » de ta galerie.',
      '“NUQTA” album in your gallery.', 'ألبوم « NUQTA » في معرض الصور.');
  String get share => _('Partager', 'Share', 'مشاركة');
  String get copyDesc => _('Copier la description', 'Copy the description',
      'نسخ الوصف');
  String get copied => _(
      'Description copiée — colle-la dans TikTok/Instagram/YouTube.',
      'Description copied — paste it into TikTok/Instagram/YouTube.',
      'تم نسخ الوصف — ألصقه في تيك توك/إنستغرام/يوتيوب.');
  String get otherVideo => _('Autre vidéo', 'New video', 'فيديو آخر');
  String missingBefore(bool video, bool content) {
    final parts = <String>[
      if (video)
        _('choisir un arrière-plan (onglet Contenu)',
            'choose a background (Content tab)',
            'اختر خلفية (تبويب المحتوى)'),
      if (content)
        _('attendre la fin du chargement versets/audio',
            'wait for verses/audio to finish loading',
            'انتظر اكتمال تحميل الآيات/الصوت'),
    ];
    return _('Avant de générer : ', 'Before generating: ', 'قبل الإنشاء: ') +
        parts.join(' · ');
  }

  // ── Génération (messages du pipeline) ──
  String renderingText(int i, int n) => _('Rendu du texte : $i/$n',
      'Rendering text: $i/$n', 'رسم النص: $i/$n');
  String get renderingTextStart =>
      _('Rendu du texte…', 'Rendering text…', 'جارٍ رسم النص…');
  String assembling(int pct, String eta) => _(
      'Assemblage des fonds : $pct %$eta',
      'Assembling backgrounds: $pct %$eta',
      'تجميع الخلفيات: $pct ٪$eta');
  String encoding(int pct, String eta) => _(
      'Encodage vidéo : $pct %$eta',
      'Encoding video: $pct %$eta',
      'ترميز الفيديو: $pct ٪$eta');
  String etaSuffix(int s) => _(' — ~$s s restantes', ' — ~$s s left',
      ' — يتبقى نحو $s ث');
  String get savingGallery => _('Enregistrement dans la galerie…',
      'Saving to gallery…', 'جارٍ الحفظ في المعرض…');
  String savedAs(String name) =>
      _('Enregistrée : $name', 'Saved: $name', 'تم الحفظ: $name');
  String get errAssemble => _(
      "Impossible d'assembler les fonds. Réessaie avec des fichiers mp4/jpg.",
      'Could not assemble the backgrounds. Try mp4/jpg files.',
      'تعذّر تجميع الخلفيات. جرّب ملفات mp4/jpg.');
  String get errEncode => _(
      "FFmpeg n'a pas pu encoder la vidéo. Réessaie avec un autre fond.",
      'FFmpeg could not encode the video. Try another background.',
      'تعذّر ترميز الفيديو. جرّب خلفية أخرى.');
  String get errNeedBackground => _(
      "Choisis d'abord un arrière-plan (vidéos, images ou couleur).",
      'First choose a background (videos, images or a color).',
      'اختر أولًا خلفية (فيديو أو صور أو لون).');
  String get errNotReady => _(
      "Le contenu ou l'audio n'est pas encore prêt.",
      'The content or audio is not ready yet.',
      'المحتوى أو الصوت غير جاهز بعد.');
  String errGeneric(Object e) => _('Échec de la génération : $e',
      'Generation failed: $e', 'فشل الإنشاء: $e');
  String errTooManyImages(int max) => _(
      'Trop d’images pour la durée de la récitation — garde au plus $max '
      'image(s), ou allonge la récitation.',
      'Too many images for the recitation duration — keep at most $max '
      'image(s), or use a longer recitation.',
      'عدد الصور كبير مقارنة بمدة التلاوة — أبقِ $max صورة كحد أقصى أو '
      'أطل التلاوة.');
  String audioUnavailable(String reciter, Object e) => _(
      'Audio de $reciter indisponible — vérifie ta connexion puis réessaie. '
      'Détail : $e',
      'Audio for $reciter unavailable — check your connection and retry. '
      'Details: $e',
      'صوت $reciter غير متاح — تحقق من الاتصال وأعد المحاولة. التفاصيل: $e');

  // ── Image-citation ──
  String get quoteTitle =>
      _('Image-citation (PNG)', 'Quote image (PNG)', 'صورة اقتباس (PNG)');
  String get quoteSubtitle => _(
      'Images fixes 1080×1920 avec ton style et ta signature actuels.',
      'Still 1080×1920 images with your current style and signature.',
      'صور ثابتة 1080×1920 بنمطك وتوقيعك الحاليين.');
  String get verseLabel => _('Verset', 'Verse', 'الآية');
  String allVerses(int n) => _('Tous les versets ($n)',
      'All verses ($n)', 'كل الآيات ($n)');
  String get backgroundLabel => _('Fond', 'Background', 'الخلفية');
  String get pickImage => _('Image…', 'Image…', 'صورة…');
  String get saveOne => _("Enregistrer l'image", 'Save the image',
      'حفظ الصورة');
  String saveMany(int n) => _('Générer les $n images',
      'Generate the $n images', 'إنشاء $n صورة');
  String generatingImages(int i, int n) =>
      _('Image $i/$n…', 'Image $i/$n…', 'الصورة $i/$n…');
  String imageSaved(String name) => _(
      'Image enregistrée dans la galerie : $name',
      'Image saved to gallery: $name',
      'تم حفظ الصورة في المعرض: $name');
  String imagesSaved(int n) => _(
      '$n images enregistrées dans la galerie (album NUQTA).',
      '$n images saved to gallery (NUQTA album).',
      'تم حفظ $n صورة في المعرض (ألبوم NUQTA).');
  String exportError(Object e) =>
      _('Export impossible — $e', 'Export failed — $e', 'فشل التصدير — $e');
  String quoteBgLabel(QuoteBackground bg) => switch (bg) {
        QuoteBackground.night => _('Nuit', 'Night', 'ليل'),
        QuoteBackground.black => _('Noir', 'Black', 'أسود'),
        QuoteBackground.gold => _('Or sombre', 'Dark gold', 'ذهبي داكن'),
        QuoteBackground.ivory => _('Ivoire', 'Ivory', 'عاجي'),
      };

  // ── Enums génériques ──
  String fadeColorLabel(FadeColor c) => switch (c) {
        FadeColor.black => _('Noir', 'Black', 'أسود'),
        FadeColor.white => _('Blanc', 'White', 'أبيض'),
      };
  String transitionLabel(TransitionMode t) => switch (t) {
        TransitionMode.none => _('Aucune', 'None', 'بدون'),
        TransitionMode.fade => _('Fondu', 'Fade', 'تلاشٍ'),
      };
  String qualityName(ExportQuality q) => switch (q) {
        ExportQuality.standard => _('Standard', 'Standard', 'قياسية'),
        ExportQuality.high => _('Haute', 'High', 'عالية'),
      };

  // ── Réglages / langue ──
  String get settingsTitle => _('Réglages', 'Settings', 'الإعدادات');
  String get settingsTooltip => _('Réglages', 'Settings', 'الإعدادات');
  String get languageLabel =>
      _("Langue de l'application", 'App language', 'لغة التطبيق');
  String get chooseLanguageTitle => _('Choisis ta langue',
      'Choose your language', 'اختر لغتك');
}
