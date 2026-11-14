import 'package:material_ui/material_ui.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/locale/app_localizations_fallback.dart';

// Mirror production: use the same delegate chain the app ships
// (`appLocalizationsDelegates`) rather than the generated
// `AppLocalizations.localizationsDelegates`, which only carries the legacy
// flutter_localizations delegates and therefore does not provide the
// material_ui localization types the app actually renders against.
const testLocalizationsDelegates = appLocalizationsDelegates;
const testSupportedLocales = AppLocalizations.supportedLocales;

AppLocalizations testL10n() => lookupAppLocalizations(const Locale('en'));
