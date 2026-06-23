import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
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

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportBootstrapError(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _reportBootstrapError(error, stack);
    return true;
  };

  runZonedGuarded(
    () => runApp(const AphidexBootstrapApp()),
    _reportBootstrapError,
  );
}

void _reportBootstrapError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Aphidex startup error: $error');
    if (stack != null) {
      debugPrintStack(stackTrace: stack);
    }
  }
}

class AphidexBootstrapApp extends StatefulWidget {
  const AphidexBootstrapApp({super.key});

  @override
  State<AphidexBootstrapApp> createState() => _AphidexBootstrapAppState();
}

class _AphidexBootstrapAppState extends State<AphidexBootstrapApp> {
  late Future<void> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox('aphidex');
      ReviewPromptController.instance.initialize();
      await MonetizationController.instance.initialize();
    } catch (error, stack) {
      _reportBootstrapError(error, stack);
      rethrow;
    }
  }

  void _retryStartup() {
    setState(() {
      _startupFuture = _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootstrapShell(
            child: _BootstrapErrorScreen(
              error: snapshot.error,
              onRetry: _retryStartup,
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapShell(child: _BootstrapLoadingScreen());
        }
        return const AphidexApp();
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF35586E)),
      ),
      home: Scaffold(
        body: SafeArea(child: Center(child: child)),
      ),
    );
  }
}

class _BootstrapLoadingScreen extends StatelessWidget {
  const _BootstrapLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Aphidex loaded',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text(
            'Initializing local data and services...',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  const _BootstrapErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aphidex loaded',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'The app could not finish startup. Please try again.',
            textAlign: TextAlign.center,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Retry startup')),
        ],
      ),
    );
  }
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
