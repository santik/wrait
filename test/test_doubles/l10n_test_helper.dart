import 'package:flutter/material.dart';
import 'package:wrait/l10n/app_localizations.dart';

const testLocalizationsDelegates = AppLocalizations.localizationsDelegates;
const testSupportedLocales = AppLocalizations.supportedLocales;

AppLocalizations testL10n() => lookupAppLocalizations(const Locale('en'));
