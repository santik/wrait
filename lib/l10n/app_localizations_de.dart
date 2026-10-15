// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get bootstrapTitle => 'wrait wird geöffnet';

  @override
  String get bootstrapSubtitle => 'Ihr lokales Tagebuch wird geladen';

  @override
  String get bootstrapErrorTitle => 'wrait konnte nicht geöffnet werden';

  @override
  String get bootstrapErrorSubtitle => 'bitte erneut versuchen';

  @override
  String get bootstrapRetryButton => 'erneut versuchen';

  @override
  String get mainSettingsTooltip => 'Einstellungen';

  @override
  String get mainFeedbackTooltip => 'Feedback senden';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Sprache: $displayName';
  }

  @override
  String get mainLanguageUnavailable =>
      'Sprache nicht verfügbar · bitte erneut versuchen';

  @override
  String get mainFeedbackSent => 'feedback gesendet';

  @override
  String get mainFeedbackUnavailable => 'feedback ist gerade nicht verfügbar';

  @override
  String get mainFeedbackFailed =>
      'feedback konnte nicht gesendet werden. bitte erneut versuchen';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Ausgewählte Transkriptionssprache $displayName. Öffnet die Einstellungen für die Transkriptionssprache.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Einstellungen';

  @override
  String get mainFeedbackSemanticsLabel => 'Feedback senden';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Aufnahmekontingent: insgesamt $limit, noch $remaining übrig.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit gesamt / $remaining übrig';
  }

  @override
  String get mainButtonStop => 'stopp';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'zum Schreiben tippen';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'hört zu...';

  @override
  String get statusProcessing => 'wird verarbeitet...';

  @override
  String get statusCleaningUp => 'wird aufbereitet...';

  @override
  String get statusSavedTapToRead => 'gespeichert, zum Lesen tippen';

  @override
  String get statusDeleted => 'gelöscht';

  @override
  String get statusNoConnectionDraft =>
      'keine Verbindung · als Entwurf gespeichert';

  @override
  String get statusServiceUnavailableDraft =>
      'dienst nicht verfügbar · als Entwurf gespeichert';

  @override
  String get statusServerConfigErrorDraft =>
      'serverkonfigurationsfehler · als Entwurf gespeichert';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'nicht erkannt · als Entwurf gespeichert';

  @override
  String get statusSpeechNotRecognized => 'nicht erkannt';

  @override
  String get statusApiFailedDraft =>
      'als Entwurf gespeichert · neuer Versuch folgt';

  @override
  String get statusTooShort => 'zu kurz · sprechen Sie weiter';

  @override
  String get statusNothingCaught => 'nichts erfasst · zu leise?';

  @override
  String get statusMicNeeded => 'mikrofon nötig · erneut tippen';

  @override
  String get statusMicBlocked => 'mikrofon blockiert · einstellungen antippen';

  @override
  String get statusNoConnection => 'keine Verbindung';

  @override
  String get statusServiceUnavailable => 'dienst nicht verfügbar';

  @override
  String get statusServerConfigError => 'serverkonfigurationsfehler';

  @override
  String get statusSomethingWentWrong => 'etwas ist schiefgelaufen';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Für die Aufnahme ist der Zugriff auf das Mikrofon erforderlich.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Doppeltippen, um den Mikrofonzugriff erneut anzufordern.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'Der Mikrofonzugriff für Wrait ist blockiert.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Doppeltippen, um die App-Einstellungen zu öffnen.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Statusmeldung $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '$count Eintrag',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '$count Tag',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Eintragsstatistik $displayText. Öffnet die Eintragsliste.';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsBack => 'Zurück';

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get settingsAppLock => 'App-Sperre';

  @override
  String get settingsAppLockDescription =>
      'Verwenden Sie die Bildschirmsperre Ihres Geräts, wenn Sie Wrait öffnen oder dorthin zurückkehren.';

  @override
  String get settingsAppLockUnavailable =>
      'Die App-Sperre ist in diesem Validierungs-Build nicht verfügbar.';

  @override
  String get settingsAppLockNoSecurity =>
      'Richten Sie eine Bildschirmsperre auf Ihrem Gerät ein, bevor Sie die App-Sperre aktivieren.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'Die Geräteauthentifizierung ist vorübergehend nicht verfügbar. Bitte versuchen Sie es erneut.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'Die Geräteauthentifizierung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get settingsAppLockSaveFailed =>
      'Die Einstellung für die App-Sperre konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Die Sicherheitseinstellungen des Geräts konnten nicht geöffnet werden.';

  @override
  String get settingsOpenDeviceSettings => 'Geräteeinstellungen öffnen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsThemeSaveFailed =>
      'Design konnte nicht gespeichert werden. Versuchen Sie es erneut.';

  @override
  String get settingsReminders => 'Erinnerungen';

  @override
  String get settingsRemindersToggle => 'Tägliche Erinnerungen';

  @override
  String get settingsRemindersDescription =>
      'Lass dich morgens und abends ans Tagebuchschreiben erinnern';

  @override
  String get settingsRemindersPermissionDenied =>
      'Für Erinnerungen wird die Benachrichtigungsberechtigung benötigt. Bitte aktiviere sie in den Geräteeinstellungen.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Starte deinen Tag mit einer Reflexion';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => 'Du hast heute noch Aufnahmen übrig';

  @override
  String get settingsTranscriptionLanguage => 'Transkriptionssprache';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Wählen Sie die Sprache, in der Sie sprechen, um die Transkription zu verbessern. Ist keine Sprache ausgewählt, wird sie automatisch erkannt.';

  @override
  String get settingsAutomaticDetection => 'Automatische Erkennung';

  @override
  String get settingsLoading => 'Wird geladen…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Die Transkriptionssprache konnte nicht geladen werden.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Die Sprache konnte nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get settingsTryAgain => 'Erneut versuchen';

  @override
  String get settingsActivityMessage =>
      'Beenden Sie die aktuelle Aufnahme oder Transkription, bevor Sie die Einstellungen ändern.';

  @override
  String get entryListBack => 'Zurück';

  @override
  String get entryListBackSemanticsLabel => 'Zurück zum Hauptbildschirm';

  @override
  String get entryListSearchLabel => 'Einträge durchsuchen';

  @override
  String get entryListClearSearch => 'Suche löschen';

  @override
  String get entryListImportCsv => 'CSV importieren';

  @override
  String get entryListExportCsv => 'CSV exportieren';

  @override
  String get entryListImporting => 'CSV wird importiert';

  @override
  String get entryListExporting => 'CSV wird exportiert';

  @override
  String get entryListImportingSemanticsLabel => 'Einträge werden importiert';

  @override
  String get entryListExportingSemanticsLabel => 'Einträge werden exportiert';

  @override
  String get entryListImportSemanticsLabel => 'Einträge importieren';

  @override
  String get entryListExportSemanticsLabel => 'Einträge exportieren';

  @override
  String get entryListEmpty => 'noch keine einträge';

  @override
  String get entryListNoResults => 'Keine passenden Einträge';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName wurde nach $pathLabel exportiert.';
  }

  @override
  String get entryListExportFailed =>
      'Die Einträge konnten nicht exportiert werden.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Datensätze',
      one: 'Datensatz',
    );
    return '$count $_temp0 aus $fileName importiert.';
  }

  @override
  String get entryListImportFailed =>
      'Die Einträge konnten nicht importiert werden.';

  @override
  String get entryListImportInvalidFormat =>
      'Die ausgewählte CSV-Datei ist kein gültiger Wrait-Export.';

  @override
  String get entryListImportUnreadableFile =>
      'Die ausgewählte CSV-Datei konnte nicht gelesen werden.';

  @override
  String get entryListImportFileTooLarge =>
      'Die ausgewählte CSV-Datei ist zu groß für den Import.';

  @override
  String get entryListImportStorageFailure =>
      'Die importierten Einträge konnten nicht gespeichert werden.';

  @override
  String get entryListAudioDraftPreview => 'ausstehend · neuer Versuch folgt';

  @override
  String get entryListAudioDraftStateDescription =>
      'Audio-Entwurf, noch nicht transkribiert';

  @override
  String get entryListDeleteActionLabel => 'Eintrag löschen';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Eintrag $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Zum Löschen nach rechts wischen.';

  @override
  String get entryListRowOpenHint =>
      'Doppeltippen zum Öffnen. Zum Löschen nach rechts wischen.';

  @override
  String get entryListRowDraftBadge => 'entwurf';

  @override
  String get entryListRowDraftValue => 'Entwurf';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'Entwurf, $description';
  }

  @override
  String get entryDetailSaving => 'Änderungen werden gespeichert...';

  @override
  String get entryDetailSaveFailed =>
      'Ihre Änderungen konnten nicht gespeichert werden.';

  @override
  String get entryDetailLoadFailed =>
      'Dieser Eintrag konnte nicht geladen werden.';

  @override
  String get entryDetailEditSemanticsLabel => 'Eintragstext bearbeiten';

  @override
  String get entryDetailEditHint => 'Eintrag bearbeiten';

  @override
  String get entryDetailTapToEditHint => 'Tippen, um den Eintrag zu bearbeiten';

  @override
  String get entryDetailBackSemanticsLabel => 'Zurück zu den Einträgen';

  @override
  String get entryDetailBack => 'Zurück';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Bearbeitung beenden';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Eintrag bearbeiten';

  @override
  String get entryDetailDone => 'Fertig';

  @override
  String get entryDetailEdit => 'Bearbeiten';

  @override
  String get entryDetailShareSemanticsLabel => 'Eintrag teilen';

  @override
  String get entryDetailShare => 'Teilen';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Eintrag löschen';

  @override
  String get entryDetailDelete => 'Löschen';

  @override
  String get entryDetailShareFailed =>
      'Dieser Eintrag konnte nicht geteilt werden.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wörter',
      one: '1 Wort',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Eintrag löschen?';

  @override
  String get deleteDialogBody => 'Dieser Eintrag wird endgültig entfernt.';

  @override
  String get deleteCancel => 'Abbrechen';

  @override
  String get deleteConfirm => 'Löschen';

  @override
  String get deleteCancelSemanticsLabel => 'Löschen abbrechen';

  @override
  String get deleteCancelSemanticsHint => 'Behält diesen Eintrag in der Liste.';

  @override
  String get deleteConfirmSemanticsLabel => 'Eintrag endgültig löschen';

  @override
  String get deleteConfirmSemanticsHint =>
      'Entfernt diesen Eintrag aus der Liste.';

  @override
  String get appLockTitle => 'wrait ist gesperrt';

  @override
  String get appLockSemanticsLabel => 'Wrait ist gesperrt.';

  @override
  String get appLockUnlock => 'Entsperren';

  @override
  String get appLockOpenSettings => 'Einstellungen öffnen';

  @override
  String get appLockContinueWithout => 'Ohne Sperre fortfahren';

  @override
  String get appLockStillLocked => 'weiterhin gesperrt';

  @override
  String get appLockSetUpSecurity =>
      'richten Sie die Gerätesicherheit ein, um Wrait zu schützen';

  @override
  String get appLockUnavailableTryAgain =>
      'entsperren nicht möglich · bitte erneut versuchen';

  @override
  String get appLockUnlockToContinue =>
      'Entsperren Sie Wrait, um fortzufahren.';

  @override
  String get appLockSettingsWarning =>
      'Ihr Tagebuch bleibt sichtbar, bis Sie die Gerätesicherheit einrichten.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Doppeltippen Sie auf Entsperren, um sich zu authentifizieren und fortzufahren.';

  @override
  String get appLockSemanticsHintSettings =>
      'Doppeltippen Sie auf Entsperren, um es erneut zu versuchen, oder öffnen Sie die Einstellungen, um die Gerätesicherheit einzurichten.';

  @override
  String get appLockSemanticsHintAuthInProgress =>
      'Die Authentifizierung läuft.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait konnte Ihre Datenschutzeinstellung nicht laden.';

  @override
  String get appLockPreferenceLoading =>
      'datenschutzeinstellungen werden geladen';

  @override
  String get appLockPreferenceRetry => 'Erneut versuchen';

  @override
  String get feedbackTitle => 'feedback senden';

  @override
  String get feedbackPrompt => 'Was möchten Sie uns mitteilen?';

  @override
  String get feedbackContactLabel => 'kontakt für Rückfragen (optional)';

  @override
  String get feedbackContactHint => 'beliebige Kontaktdaten';

  @override
  String get feedbackMessageLabel => 'feedback';

  @override
  String get feedbackMessageHint => 'was möchten Sie uns mitteilen?';

  @override
  String get feedbackPrivacyCopy =>
      'Geben Sie keine privaten Tagebuchinhalte an, es sei denn, Sie tippen sie selbst in Ihre Nachricht ein.';

  @override
  String get feedbackCancel => 'abbrechen';

  @override
  String get feedbackSubmit => 'senden';

  @override
  String get feedbackDismissLabel => 'Feedback schließen';

  @override
  String get feedbackCategoryBug => 'Fehler';

  @override
  String get feedbackCategoryIdea => 'Idee';

  @override
  String get feedbackCategoryConfusing => 'Unklar';

  @override
  String get feedbackCategoryPraise => 'Lob';
}
