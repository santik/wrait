import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wiredash/wiredash.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'data/preferences/theme_mode_controller.dart';
import 'l10n/app_localizations.dart';
import 'presentation/app_lock/app_lock_gate.dart';
import 'presentation/locale/app_localizations_fallback.dart';
import 'presentation/theme/wrait_theme.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) =>
      throw UnimplementedError('AppConfig must be provided at app startup.'),
);

final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter());

class WraitApp extends ConsumerWidget {
  const WraitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appConfig = ref.watch(appConfigProvider);
    final themeMode = ref.watch(
      themeModeControllerProvider.select((s) => s.themeMode),
    );

    return MaterialApp.router(
      title: 'Wrait',
      debugShowCheckedModeBanner: false,
      theme: wraitLightTheme,
      darkTheme: wraitDarkTheme,
      themeMode: themeMode,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: _buildSupportedLocales(),
      routerConfig: router,
      builder: (context, child) {
        final routerChild = child ?? const SizedBox.shrink();
        final feedbackChild = appConfig.wiredashConfigured
            ? Wiredash(
                projectId: appConfig.wiredashProjectId,
                secret: appConfig.wiredashSecret,
                environment: appConfig.wiredashEnvironment,
                child: routerChild,
              )
            : routerChild;
        return AppLockGate(child: feedbackChild);
      },
    );
  }
}

List<Locale> _buildSupportedLocales() {
  final localesByTag = <String, Locale>{};

  for (final locale in AppLocalizations.supportedLocales) {
    _addLocale(localesByTag, locale);
  }

  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    _addLocale(localesByTag, locale);
  }

  if (localesByTag.isEmpty) {
    _addLocale(localesByTag, const Locale('en', 'US'));
  }

  return localesByTag.values.toList(growable: false);
}

void _addLocale(Map<String, Locale> localesByTag, Locale locale) {
  final countryCode = locale.countryCode;
  if (countryCode != null && countryCode.isNotEmpty) {
    localesByTag.putIfAbsent(
      '${locale.languageCode}-$countryCode',
      () => Locale(locale.languageCode, countryCode),
    );
  }

  localesByTag.putIfAbsent(
    locale.languageCode,
    () => Locale(locale.languageCode),
  );
}
