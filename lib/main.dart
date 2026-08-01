import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/strings.dart';
import 'ui/editor_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: NuqtaApp()));
}

class NuqtaApp extends ConsumerWidget {
  const NuqtaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider).lang;
    return MaterialApp(
      title: 'NUQTA',
      debugShowCheckedModeBanner: false,
      locale: Locale(lang.code),
      supportedLocales: [
        for (final l in AppLanguage.values) Locale(l.code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RTL réel pour l'arabe : toute l'interface est inversée.
      builder: (context, child) => Directionality(
        textDirection:
            lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF26A69A),
        scaffoldBackgroundColor: const Color(0xFF0E1113),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.onDrag,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}
