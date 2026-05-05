import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/locale_controller.dart';
import 'controllers/monetization_controller.dart';
import 'controllers/review_prompt_controller.dart';
import 'controllers/theme_controller.dart';
import 'i18n/app_localizations.dart';
import 'screens/enemy_list_screen.dart';
import 'widgets/tutorial_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('aphidex');
  ReviewPromptController.instance.initialize();
  await MonetizationController.instance.initialize();
  runApp(const AphidexApp());
}

class AphidexApp extends StatelessWidget {
  const AphidexApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([theme.theme, locale.preference]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: ReviewPromptController.navigatorKey,
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) =>
              TutorialHost(child: child ?? const SizedBox.shrink()),
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            final resolved = LocaleController.resolveSupportedLocale(
              deviceLocale,
            );
            return supportedLocales.firstWhere(
              (item) => item.languageCode == resolved.languageCode,
              orElse: () => const Locale('en'),
            );
          },
          themeMode: theme.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
          ),
          home: const EnemyListScreen(),
        );
      },
    );
  }
}
