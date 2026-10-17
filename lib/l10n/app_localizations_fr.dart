// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get bootstrapTitle => 'ouverture de wrait';

  @override
  String get bootstrapSubtitle => 'chargement de votre journal local';

  @override
  String get bootstrapErrorTitle => 'impossible d’ouvrir wrait';

  @override
  String get bootstrapErrorSubtitle => 'réessayez';

  @override
  String get bootstrapRetryButton => 'réessayer';

  @override
  String get mainSettingsTooltip => 'Réglages';

  @override
  String get mainFeedbackTooltip => 'Envoyer un commentaire';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Langue : $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Langue indisponible · réessayez';

  @override
  String get mainFeedbackSent => 'commentaire envoyé';

  @override
  String get mainFeedbackUnavailable =>
      'l’envoi de commentaires est indisponible pour le moment';

  @override
  String get mainFeedbackFailed =>
      'le commentaire n’a pas pu être envoyé. réessayez';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Langue de transcription sélectionnée : $displayName. Ouvre les réglages de la langue de transcription.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Réglages';

  @override
  String get mainFeedbackSemanticsLabel => 'Envoyer un commentaire';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Quota d’enregistrement : $limit au total et $remaining restants.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit au total / $remaining restants';
  }

  @override
  String get mainButtonStop => 'stop';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'appuyez sur le bouton pour écrire';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'écoute en cours...';

  @override
  String get statusProcessing => 'traitement en cours...';

  @override
  String get statusCleaningUp => 'nettoyage en cours...';

  @override
  String get statusSavedTapToRead => 'enregistré, appuyez pour lire';

  @override
  String get statusDeleted => 'supprimé';

  @override
  String get statusNoConnectionDraft =>
      'pas de connexion · enregistré en brouillon';

  @override
  String get statusServiceUnavailableDraft =>
      'service indisponible · enregistré en brouillon';

  @override
  String get statusServerConfigErrorDraft =>
      'erreur de config serveur · enregistré en brouillon';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'non reconnu · enregistré en brouillon';

  @override
  String get statusSpeechNotRecognized => 'non reconnu';

  @override
  String get statusApiFailedDraft =>
      'enregistré en brouillon · nouvelle tentative à venir';

  @override
  String get statusTooShort => 'trop court · continuez à parler';

  @override
  String get statusNothingCaught => 'rien capté · trop bas ?';

  @override
  String get statusMicNeeded => 'micro requis · appuyez à nouveau';

  @override
  String get statusMicBlocked => 'micro bloqué · appuyez sur réglages';

  @override
  String get statusNoConnection => 'pas de connexion';

  @override
  String get statusServiceUnavailable => 'service indisponible';

  @override
  String get statusServerConfigError => 'erreur de config serveur';

  @override
  String get statusSomethingWentWrong => 'une erreur s’est produite';

  @override
  String get statusMicNeededSemanticsLabel =>
      'L’accès au microphone est nécessaire pour démarrer l’enregistrement.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Appuyez deux fois pour demander à nouveau l’accès au microphone.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'L’accès au microphone est bloqué pour Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Appuyez deux fois pour ouvrir les réglages de l’app.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Message d’état : $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '$count entrée',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Statistiques des entrées : $displayText. Ouvre la liste des entrées.';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsBack => 'Retour';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsAppLock => 'Verrouillage de l’app';

  @override
  String get settingsAppLockDescription =>
      'Utilisez le verrouillage d’écran de votre appareil lorsque vous ouvrez Wrait ou y revenez.';

  @override
  String get settingsAppLockUnavailable =>
      'Le verrouillage de l’app n’est pas disponible dans cette version de validation.';

  @override
  String get settingsAppLockNoSecurity =>
      'Configurez un verrouillage d’écran sur l’appareil avant d’activer le verrouillage de l’app.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'L’authentification de l’appareil est temporairement indisponible. Réessayez.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'L’authentification n’est pas disponible sur cet appareil.';

  @override
  String get settingsAppLockSaveFailed =>
      'Impossible d’enregistrer le réglage du verrouillage de l’app. Réessayez.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Impossible d’ouvrir les réglages de sécurité de l’appareil.';

  @override
  String get settingsOpenDeviceSettings => 'Ouvrir les réglages de l’appareil';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeSaveFailed =>
      'Impossible d’enregistrer le thème. Réessayez.';

  @override
  String get settingsReminders => 'Rappels';

  @override
  String get settingsRemindersToggle => 'Rappels quotidiens';

  @override
  String get settingsRemindersDescription =>
      'Reçois des rappels pour écrire dans ton journal le matin et le soir';

  @override
  String get settingsRemindersPermissionDenied =>
      'L\'autorisation de notifications est nécessaire pour les rappels. Active-la dans les paramètres de l\'appareil.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Commence ta journée par une réflexion';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody =>
      'Il te reste encore des enregistrements aujourd\'hui';

  @override
  String get settingsTranscriptionLanguage => 'Langue de transcription';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Choisissez la langue que vous parlez pour améliorer la transcription. La détection automatique est utilisée lorsqu’aucune langue n’est sélectionnée.';

  @override
  String get settingsAutomaticDetection => 'Détection automatique';

  @override
  String get settingsLoading => 'Chargement…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Impossible de charger la langue de transcription.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Impossible d’enregistrer la langue. Réessayez.';

  @override
  String get settingsTryAgain => 'Réessayer';

  @override
  String get settingsActivityMessage =>
      'Terminez l’enregistrement ou la transcription en cours avant de modifier les réglages.';

  @override
  String get entryListBack => 'Retour';

  @override
  String get entryListBackSemanticsLabel => 'Retour à l’écran principal';

  @override
  String get entryListSearchLabel => 'Rechercher des entrées';

  @override
  String get entryListClearSearch => 'Effacer la recherche';

  @override
  String get entryListImportCsv => 'Importer un CSV';

  @override
  String get entryListExportCsv => 'Exporter en CSV';

  @override
  String get entryListImporting => 'Importation du CSV';

  @override
  String get entryListExporting => 'Exportation du CSV';

  @override
  String get entryListImportingSemanticsLabel => 'Importation des entrées';

  @override
  String get entryListExportingSemanticsLabel => 'Exportation des entrées';

  @override
  String get entryListImportSemanticsLabel => 'Importer des entrées';

  @override
  String get entryListExportSemanticsLabel => 'Exporter des entrées';

  @override
  String get entryListEmpty => 'aucune entrée pour l’instant';

  @override
  String get entryListNoResults => 'Aucune entrée correspondante';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName exporté vers $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'Impossible d’exporter les entrées.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'enregistrements importés',
      one: 'enregistrement importé',
    );
    return '$count $_temp0 depuis $fileName.';
  }

  @override
  String get entryListImportFailed => 'Impossible d’importer les entrées.';

  @override
  String get entryListImportInvalidFormat =>
      'Le CSV sélectionné n’est pas un export Wrait valide.';

  @override
  String get entryListImportUnreadableFile =>
      'Impossible de lire le fichier CSV sélectionné.';

  @override
  String get entryListImportFileTooLarge =>
      'Le CSV sélectionné est trop volumineux pour être importé.';

  @override
  String get entryListImportStorageFailure =>
      'Impossible d’enregistrer les entrées importées.';

  @override
  String get entryListAudioDraftPreview =>
      'en attente · nouvelle tentative à venir';

  @override
  String get entryListAudioDraftStateDescription =>
      'Brouillon audio, pas encore transcrit';

  @override
  String get entryListDeleteActionLabel => 'Supprimer l’entrée';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Entrée $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Balayez vers la droite pour supprimer.';

  @override
  String get entryListRowOpenHint =>
      'Appuyez deux fois pour ouvrir. Balayez vers la droite pour supprimer.';

  @override
  String get entryListRowDraftBadge => 'brouillon';

  @override
  String get entryListRowDraftValue => 'brouillon';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'brouillon, $description';
  }

  @override
  String get entryDetailSaving => 'Enregistrement des modifications...';

  @override
  String get entryDetailSaveFailed =>
      'Impossible d’enregistrer vos modifications.';

  @override
  String get entryDetailLoadFailed => 'Impossible de charger cette entrée.';

  @override
  String get entryDetailEditSemanticsLabel => 'Modifier le texte de l’entrée';

  @override
  String get entryDetailEditHint => 'Modifiez votre entrée';

  @override
  String get entryDetailTapToEditHint => 'Appuyez pour modifier l’entrée';

  @override
  String get entryDetailBackSemanticsLabel => 'Retour aux entrées';

  @override
  String get entryDetailBack => 'Retour';

  @override
  String get entryDetailFinishEditingSemanticsLabel =>
      'Terminer la modification';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Modifier l’entrée';

  @override
  String get entryDetailDone => 'Terminé';

  @override
  String get entryDetailEdit => 'Modifier';

  @override
  String get entryDetailShareSemanticsLabel => 'Partager l’entrée';

  @override
  String get entryDetailShare => 'Partager';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Supprimer l’entrée';

  @override
  String get entryDetailDelete => 'Supprimer';

  @override
  String get entryDetailShareFailed => 'Impossible de partager cette entrée.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Supprimer l’entrée ?';

  @override
  String get deleteDialogBody => 'Cette entrée sera définitivement supprimée.';

  @override
  String get deleteCancel => 'Annuler';

  @override
  String get deleteConfirm => 'Supprimer';

  @override
  String get deleteCancelSemanticsLabel => 'Annuler la suppression';

  @override
  String get deleteCancelSemanticsHint =>
      'Conserve cette entrée dans la liste.';

  @override
  String get deleteConfirmSemanticsLabel => 'Supprimer définitivement l’entrée';

  @override
  String get deleteConfirmSemanticsHint => 'Retire cette entrée de la liste.';

  @override
  String get appLockTitle => 'wrait est verrouillé';

  @override
  String get appLockSemanticsLabel => 'Wrait est verrouillé.';

  @override
  String get appLockUnlock => 'Déverrouiller';

  @override
  String get appLockOpenSettings => 'Ouvrir les réglages';

  @override
  String get appLockContinueWithout => 'Continuer sans verrouillage';

  @override
  String get appLockStillLocked => 'toujours verrouillé';

  @override
  String get appLockSetUpSecurity =>
      'configurez la sécurité de l’appareil pour protéger Wrait';

  @override
  String get appLockUnavailableTryAgain =>
      'déverrouillage indisponible · réessayez';

  @override
  String get appLockUnlockToContinue => 'Déverrouillez Wrait pour continuer.';

  @override
  String get appLockSettingsWarning =>
      'Votre journal sera visible tant que vous n’aurez pas configuré la sécurité de l’appareil.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Appuyez deux fois sur Déverrouiller pour vous authentifier et continuer.';

  @override
  String get appLockSemanticsHintSettings =>
      'Appuyez deux fois sur Déverrouiller pour réessayer, ou ouvrez les réglages pour configurer la sécurité de l’appareil.';

  @override
  String get appLockSemanticsHintAuthInProgress => 'Authentification en cours.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait n’a pas pu charger votre réglage de confidentialité.';

  @override
  String get appLockPreferenceLoading =>
      'chargement des réglages de confidentialité';

  @override
  String get appLockPreferenceRetry => 'Réessayer';

  @override
  String get feedbackTitle => 'envoyer un commentaire';

  @override
  String get feedbackPrompt => 'Que souhaitez-vous partager ?';

  @override
  String get feedbackContactLabel => 'contact pour la réponse (facultatif)';

  @override
  String get feedbackContactHint => 'toute information de contact';

  @override
  String get feedbackMessageLabel => 'commentaire';

  @override
  String get feedbackMessageHint => 'que souhaitez-vous partager ?';

  @override
  String get feedbackPrivacyCopy =>
      'N’incluez pas de contenu privé de votre journal, sauf si vous choisissez de le saisir dans votre message.';

  @override
  String get feedbackCancel => 'annuler';

  @override
  String get feedbackSubmit => 'envoyer';

  @override
  String get feedbackDismissLabel => 'Fermer le commentaire';

  @override
  String get feedbackCategoryBug => 'Bug';

  @override
  String get feedbackCategoryIdea => 'Idée';

  @override
  String get feedbackCategoryConfusing => 'Peu clair';

  @override
  String get feedbackCategoryPraise => 'Éloge';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsManage => 'Gérer les tags';

  @override
  String get tagsAdd => 'Ajouter un tag';

  @override
  String get tagsAddHint => 'Nom du tag';

  @override
  String get tagsEmpty => 'Aucun tag';

  @override
  String tagsLimitReached(int max) {
    return 'Limite de tags atteinte ($max)';
  }

  @override
  String get tagsDeleteConfirmTitle => 'Supprimer le tag ?';

  @override
  String get tagsDeleteConfirmBody =>
      'Ce tag sera retiré de toutes les entrées.';

  @override
  String get tagsDeleteConfirm => 'Supprimer';

  @override
  String get tagsDeleteCancel => 'Annuler';

  @override
  String tagsNameTooLong(int max) {
    return 'Le nom doit faire $max caractères ou moins';
  }

  @override
  String get tagsNameDuplicate => 'Ce tag existe déjà';

  @override
  String get tagsCreateFailed => 'Impossible de créer le tag';

  @override
  String get tagsDeleteFailed => 'Impossible de supprimer le tag';

  @override
  String get tagsFilterAll => 'Tous';

  @override
  String get tagsFilterClear => 'Effacer le filtre';

  @override
  String get tagsNoEntriesWithTag => 'Aucune entrée avec ce tag';

  @override
  String get tagsAssign => 'Tags';

  @override
  String get tagsAssignDone => 'Terminé';

  @override
  String tagsAssignCreate(String name) {
    return 'Créer \"$name\"';
  }

  @override
  String tagsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$_temp0';
  }

  @override
  String get tagsSearchIncluded => 'La recherche inclut les noms de tags';
}
