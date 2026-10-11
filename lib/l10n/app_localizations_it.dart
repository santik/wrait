// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get bootstrapTitle => 'apertura di wrait';

  @override
  String get bootstrapSubtitle => 'caricamento del tuo diario locale';

  @override
  String get bootstrapErrorTitle => 'impossibile aprire wrait';

  @override
  String get bootstrapErrorSubtitle => 'riprova';

  @override
  String get bootstrapRetryButton => 'riprova';

  @override
  String get mainSettingsTooltip => 'Impostazioni';

  @override
  String get mainFeedbackTooltip => 'Invia feedback';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Lingua: $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Lingua non disponibile · riprova';

  @override
  String get mainFeedbackSent => 'feedback inviato';

  @override
  String get mainFeedbackUnavailable =>
      'il feedback non è disponibile al momento';

  @override
  String get mainFeedbackFailed => 'impossibile inviare il feedback. riprova';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Lingua di trascrizione selezionata: $displayName. Apre le impostazioni della lingua di trascrizione.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Impostazioni';

  @override
  String get mainFeedbackSemanticsLabel => 'Invia feedback';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Quota di registrazione: $limit in totale e $remaining rimaste.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit in totale / $remaining rimaste';
  }

  @override
  String get mainButtonStop => 'stop';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'tocca il pulsante per scrivere';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'in ascolto...';

  @override
  String get statusProcessing => 'elaborazione...';

  @override
  String get statusCleaningUp => 'revisione del testo...';

  @override
  String get statusSavedTapToRead => 'salvato, tocca per leggere';

  @override
  String get statusDeleted => 'eliminato';

  @override
  String get statusNoConnectionDraft =>
      'nessuna connessione · salvato come bozza';

  @override
  String get statusServiceUnavailableDraft =>
      'servizio non disponibile · salvato come bozza';

  @override
  String get statusServerConfigErrorDraft =>
      'errore di configurazione del server · salvato come bozza';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'non riconosciuto · salvato come bozza';

  @override
  String get statusSpeechNotRecognized => 'non riconosciuto';

  @override
  String get statusApiFailedDraft => 'salvato come bozza · riproverà';

  @override
  String get statusTooShort => 'troppo breve · continua a parlare';

  @override
  String get statusNothingCaught => 'nulla rilevato · troppo piano?';

  @override
  String get statusMicNeeded => 'serve il microfono · tocca di nuovo';

  @override
  String get statusMicBlocked => 'microfono bloccato · tocca impostazioni';

  @override
  String get statusNoConnection => 'nessuna connessione';

  @override
  String get statusServiceUnavailable => 'servizio non disponibile';

  @override
  String get statusServerConfigError => 'errore di configurazione del server';

  @override
  String get statusSomethingWentWrong => 'qualcosa è andato storto';

  @override
  String get statusMicNeededSemanticsLabel =>
      'L\'accesso al microfono è necessario per avviare la registrazione.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Tocca due volte per richiedere di nuovo l\'accesso al microfono.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'L\'accesso al microfono è bloccato per Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Tocca due volte per aprire le impostazioni dell\'app.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Messaggio di stato: $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci',
      one: '$count voce',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '$count giorno',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Statistiche delle voci: $displayText. Apre l\'elenco delle voci.';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsBack => 'Indietro';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAppLock => 'Blocco app';

  @override
  String get settingsAppLockDescription =>
      'Usa il blocco schermo del dispositivo quando apri Wrait o ci ritorni.';

  @override
  String get settingsAppLockUnavailable =>
      'Il blocco app non è disponibile in questa build di validazione.';

  @override
  String get settingsAppLockNoSecurity =>
      'Imposta un blocco schermo sul dispositivo prima di attivare il blocco app.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'L\'autenticazione del dispositivo è temporaneamente non disponibile. Riprova.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'L\'autenticazione del dispositivo non è disponibile su questo dispositivo.';

  @override
  String get settingsAppLockSaveFailed =>
      'Impossibile salvare l\'impostazione del blocco app. Riprova.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Impossibile aprire le impostazioni di sicurezza del dispositivo.';

  @override
  String get settingsOpenDeviceSettings => 'Apri impostazioni del dispositivo';

  @override
  String get settingsTranscriptionLanguage => 'Lingua di trascrizione';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Scegli la lingua che parli per migliorare la trascrizione. Se non selezioni nessuna lingua, viene usato il rilevamento automatico.';

  @override
  String get settingsAutomaticDetection => 'Rilevamento automatico';

  @override
  String get settingsLoading => 'Caricamento…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Impossibile caricare la lingua di trascrizione.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Impossibile salvare la lingua. Riprova.';

  @override
  String get settingsTryAgain => 'Riprova';

  @override
  String get settingsActivityMessage =>
      'Termina la registrazione o la trascrizione in corso prima di modificare le impostazioni.';

  @override
  String get entryListBack => 'Indietro';

  @override
  String get entryListBackSemanticsLabel => 'Torna alla schermata principale';

  @override
  String get entryListSearchLabel => 'Cerca nelle voci';

  @override
  String get entryListClearSearch => 'Cancella ricerca';

  @override
  String get entryListImportCsv => 'Importa CSV';

  @override
  String get entryListExportCsv => 'Esporta CSV';

  @override
  String get entryListImporting => 'Importazione CSV';

  @override
  String get entryListExporting => 'Esportazione CSV';

  @override
  String get entryListImportingSemanticsLabel => 'Importazione delle voci';

  @override
  String get entryListExportingSemanticsLabel => 'Esportazione delle voci';

  @override
  String get entryListImportSemanticsLabel => 'Importa voci';

  @override
  String get entryListExportSemanticsLabel => 'Esporta voci';

  @override
  String get entryListEmpty => 'ancora nessuna voce';

  @override
  String get entryListNoResults => 'Nessuna voce corrispondente';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName esportato in $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'Impossibile esportare le voci.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'record',
      one: 'record',
    );
    return 'Importati $count $_temp0 da $fileName.';
  }

  @override
  String get entryListImportFailed => 'Impossibile importare le voci.';

  @override
  String get entryListImportInvalidFormat =>
      'Il CSV selezionato non è un\'esportazione valida di Wrait.';

  @override
  String get entryListImportUnreadableFile =>
      'Impossibile leggere il file CSV selezionato.';

  @override
  String get entryListImportFileTooLarge =>
      'Il CSV selezionato è troppo grande per essere importato.';

  @override
  String get entryListImportStorageFailure =>
      'Impossibile salvare le voci importate.';

  @override
  String get entryListAudioDraftPreview => 'in attesa · riproverà';

  @override
  String get entryListAudioDraftStateDescription =>
      'Bozza audio, non ancora trascritta';

  @override
  String get entryListDeleteActionLabel => 'Elimina voce';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Voce $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Scorri verso destra per eliminare.';

  @override
  String get entryListRowOpenHint =>
      'Tocca due volte per aprire. Scorri verso destra per eliminare.';

  @override
  String get entryListRowDraftBadge => 'bozza';

  @override
  String get entryListRowDraftValue => 'bozza';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'bozza, $description';
  }

  @override
  String get entryDetailSaving => 'Salvataggio delle modifiche...';

  @override
  String get entryDetailSaveFailed => 'Impossibile salvare le modifiche.';

  @override
  String get entryDetailLoadFailed => 'Impossibile caricare questa voce.';

  @override
  String get entryDetailEditSemanticsLabel => 'Modifica il testo della voce';

  @override
  String get entryDetailEditHint => 'Modifica la tua voce';

  @override
  String get entryDetailTapToEditHint => 'Tocca per modificare la voce';

  @override
  String get entryDetailBackSemanticsLabel => 'Torna alle voci';

  @override
  String get entryDetailBack => 'Indietro';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Termina la modifica';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Modifica voce';

  @override
  String get entryDetailDone => 'Fine';

  @override
  String get entryDetailEdit => 'Modifica';

  @override
  String get entryDetailShareSemanticsLabel => 'Condividi voce';

  @override
  String get entryDetailShare => 'Condividi';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Elimina voce';

  @override
  String get entryDetailDelete => 'Elimina';

  @override
  String get entryDetailShareFailed => 'Impossibile condividere questa voce.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parole',
      one: '1 parola',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Eliminare la voce?';

  @override
  String get deleteDialogBody => 'Questa voce verrà rimossa definitivamente.';

  @override
  String get deleteCancel => 'Annulla';

  @override
  String get deleteConfirm => 'Elimina';

  @override
  String get deleteCancelSemanticsLabel => 'Annulla eliminazione';

  @override
  String get deleteCancelSemanticsHint => 'Mantiene questa voce nell\'elenco.';

  @override
  String get deleteConfirmSemanticsLabel => 'Elimina voce definitivamente';

  @override
  String get deleteConfirmSemanticsHint => 'Rimuove questa voce dall\'elenco.';

  @override
  String get appLockTitle => 'wrait è bloccato';

  @override
  String get appLockSemanticsLabel => 'Wrait è bloccato.';

  @override
  String get appLockUnlock => 'Sblocca';

  @override
  String get appLockOpenSettings => 'Apri impostazioni';

  @override
  String get appLockContinueWithout => 'Continua senza blocco';

  @override
  String get appLockStillLocked => 'ancora bloccato';

  @override
  String get appLockSetUpSecurity =>
      'imposta la sicurezza del dispositivo per proteggere Wrait';

  @override
  String get appLockUnavailableTryAgain => 'sblocco non disponibile · riprova';

  @override
  String get appLockUnlockToContinue => 'Sblocca Wrait per continuare.';

  @override
  String get appLockSettingsWarning =>
      'Il tuo diario sarà visibile finché non imposti la sicurezza del dispositivo.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Tocca due volte Sblocca per autenticarti e continuare.';

  @override
  String get appLockSemanticsHintSettings =>
      'Tocca due volte Sblocca per riprovare, oppure apri le impostazioni per configurare la sicurezza del dispositivo.';

  @override
  String get appLockSemanticsHintAuthInProgress => 'Autenticazione in corso.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait non è riuscito a caricare la tua impostazione sulla privacy.';

  @override
  String get appLockPreferenceLoading =>
      'caricamento delle impostazioni sulla privacy';

  @override
  String get appLockPreferenceRetry => 'Riprova';

  @override
  String get feedbackTitle => 'invia feedback';

  @override
  String get feedbackPrompt => 'Cosa vorresti condividere?';

  @override
  String get feedbackContactLabel => 'contatto per la risposta (facoltativo)';

  @override
  String get feedbackContactHint => 'qualsiasi recapito';

  @override
  String get feedbackMessageLabel => 'feedback';

  @override
  String get feedbackMessageHint => 'cosa vorresti condividere?';

  @override
  String get feedbackPrivacyCopy =>
      'Non includere contenuti privati del diario, a meno che tu non scelga di scriverli nel messaggio.';

  @override
  String get feedbackCancel => 'annulla';

  @override
  String get feedbackSubmit => 'invia';

  @override
  String get feedbackDismissLabel => 'Chiudi feedback';

  @override
  String get feedbackCategoryBug => 'Bug';

  @override
  String get feedbackCategoryIdea => 'Idea';

  @override
  String get feedbackCategoryConfusing => 'Poco chiaro';

  @override
  String get feedbackCategoryPraise => 'Complimenti';
}
