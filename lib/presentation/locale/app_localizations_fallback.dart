import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/app_localizations.dart';

/// Loads [AppLocalizations] for any locale, falling back to English when the
/// app has no translation for it.
///
/// The transcription language can be set to languages the UI is not translated
/// into; without this the app locale would have no [AppLocalizations] at all.
class FallbackAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const FallbackAppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) {
    if (AppLocalizations.delegate.isSupported(locale)) {
      return AppLocalizations.delegate.load(locale);
    }
    return SynchronousFuture<AppLocalizations>(
      lookupAppLocalizations(const Locale('en')),
    );
  }

  @override
  bool shouldReload(FallbackAppLocalizationsDelegate old) => false;
}

const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  FallbackAppLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
