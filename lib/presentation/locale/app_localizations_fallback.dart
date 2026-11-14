import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
// Imported with a prefix so both the legacy (package:flutter/material.dart) and
// the new (material_ui/cupertino_ui) Global*Localizations can be referenced — on
// Flutter 3.50 they are different *types*, and widgets look up their own type.
import 'package:flutter_localizations/flutter_localizations.dart' as legacy_l10n;

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
  // New (Flutter 3.50) material_ui / cupertino_ui localizations, for the app's
  // own widgets and anything using package:material_ui/package:cupertino_ui.
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  // Legacy localizations, for dependencies that still import
  // package:flutter/material.dart (e.g. Wiredash 2.6.1): their
  // MaterialLocalizations/CupertinoLocalizations are *different types* than the
  // material_ui ones, so without these a Material widget from such a dependency
  // would throw on MaterialLocalizations.of(context). Localizations keys by
  // type, so both families coexist. These symbols are deprecated on 3.50 but
  // remain necessary until every such dependency migrates off legacy material.
  // ignore: deprecated_member_use
  legacy_l10n.GlobalMaterialLocalizations.delegate,
  // ignore: deprecated_member_use
  legacy_l10n.GlobalCupertinoLocalizations.delegate,
  legacy_l10n.GlobalWidgetsLocalizations.delegate,
];
