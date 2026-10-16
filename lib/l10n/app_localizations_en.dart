// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get bootstrapTitle => 'opening wrait';

  @override
  String get bootstrapSubtitle => 'loading your local journal';

  @override
  String get bootstrapErrorTitle => 'could not open wrait';

  @override
  String get bootstrapErrorSubtitle => 'try again';

  @override
  String get bootstrapRetryButton => 'retry';

  @override
  String get mainSettingsTooltip => 'Settings';

  @override
  String get mainFeedbackTooltip => 'Send feedback';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Language: $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Language unavailable · try again';

  @override
  String get mainFeedbackSent => 'feedback sent';

  @override
  String get mainFeedbackUnavailable => 'feedback is unavailable right now';

  @override
  String get mainFeedbackFailed => 'feedback could not be sent. try again';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Selected transcription language $displayName. Opens transcription language settings.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Settings';

  @override
  String get mainFeedbackSemanticsLabel => 'Send feedback';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Recording quota $limit total and $remaining left.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit total / $remaining left';
  }

  @override
  String get mainButtonStop => 'stop';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'tap button to write';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'listening...';

  @override
  String get statusProcessing => 'processing...';

  @override
  String get statusCleaningUp => 'cleaning up...';

  @override
  String get statusSavedTapToRead => 'saved, tap to read';

  @override
  String get statusDeleted => 'deleted';

  @override
  String get statusNoConnectionDraft => 'no connection · saved as draft';

  @override
  String get statusServiceUnavailableDraft =>
      'service unavailable · saved as draft';

  @override
  String get statusServerConfigErrorDraft =>
      'server config error · saved as draft';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'not recognized · saved as draft';

  @override
  String get statusSpeechNotRecognized => 'not recognized';

  @override
  String get statusApiFailedDraft => 'saved as draft · will retry';

  @override
  String get statusTooShort => 'too short · keep talking';

  @override
  String get statusNothingCaught => 'nothing caught · too quiet?';

  @override
  String get statusMicNeeded => 'mic needed · tap again';

  @override
  String get statusMicBlocked => 'mic blocked · tap settings';

  @override
  String get statusNoConnection => 'no connection';

  @override
  String get statusServiceUnavailable => 'service unavailable';

  @override
  String get statusServerConfigError => 'server config error';

  @override
  String get statusSomethingWentWrong => 'something went wrong';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Microphone access is required to start recording.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Double tap to request microphone access again.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'Microphone access is blocked for Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Double tap to open app settings.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Status message $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '$count entry',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Entry stats $displayText. Opens the entry list.';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsBack => 'Back';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockDescription =>
      'Use your device\'s screen lock when you open or return to Wrait.';

  @override
  String get settingsAppLockUnavailable =>
      'App lock is unavailable in this validation build.';

  @override
  String get settingsAppLockNoSecurity =>
      'Set up a device screen lock before enabling app lock.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'Device authentication is temporarily unavailable. Try again.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'Device authentication is unavailable on this device.';

  @override
  String get settingsAppLockSaveFailed =>
      'Could not save the app-lock setting. Try again.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Could not open device security settings.';

  @override
  String get settingsOpenDeviceSettings => 'Open device settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSaveFailed => 'Could not save theme. Try again.';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsRemindersToggle => 'Daily reminders';

  @override
  String get settingsRemindersDescription =>
      'Get reminded to journal in the morning and evening';

  @override
  String get settingsRemindersPermissionDenied =>
      'Notification permission is required for reminders. Please enable it in your device settings.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => 'Start your day with a reflection';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => 'You still have recordings left today';

  @override
  String get settingsTranscriptionLanguage => 'Transcription language';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Choose the language you speak to improve transcription. Automatic detection is used when no language is selected.';

  @override
  String get settingsAutomaticDetection => 'Automatic detection';

  @override
  String get settingsLoading => 'Loading…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Could not load the transcription language.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Could not save language. Try again.';

  @override
  String get settingsTryAgain => 'Try again';

  @override
  String get settingsActivityMessage =>
      'Finish the current recording or transcription before changing settings.';

  @override
  String get entryListBack => 'Back';

  @override
  String get entryListBackSemanticsLabel => 'Back to main screen';

  @override
  String get entryListSearchLabel => 'Search entries';

  @override
  String get entryListClearSearch => 'Clear search';

  @override
  String get entryListImportCsv => 'Import CSV';

  @override
  String get entryListExportCsv => 'Export CSV';

  @override
  String get entryListImporting => 'Importing CSV';

  @override
  String get entryListExporting => 'Exporting CSV';

  @override
  String get entryListImportingSemanticsLabel => 'Importing entries';

  @override
  String get entryListExportingSemanticsLabel => 'Exporting entries';

  @override
  String get entryListImportSemanticsLabel => 'Import entries';

  @override
  String get entryListExportSemanticsLabel => 'Export entries';

  @override
  String get entryListEmpty => 'no entries yet';

  @override
  String get entryListNoResults => 'No matching entries';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return 'Exported $fileName to $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'Could not export entries.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'records',
      one: 'record',
    );
    return 'Imported $count $_temp0 from $fileName.';
  }

  @override
  String get entryListImportFailed => 'Could not import entries.';

  @override
  String get entryListImportInvalidFormat =>
      'Selected CSV is not a valid Wrait export.';

  @override
  String get entryListImportUnreadableFile =>
      'Could not read the selected CSV file.';

  @override
  String get entryListImportFileTooLarge =>
      'Selected CSV is too large to import.';

  @override
  String get entryListImportStorageFailure =>
      'Could not save imported entries.';

  @override
  String get entryListAudioDraftPreview => 'pending · will retry';

  @override
  String get entryListAudioDraftStateDescription =>
      'Audio draft, not yet transcribed';

  @override
  String get entryListDeleteActionLabel => 'Delete entry';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Entry $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Swipe right to delete.';

  @override
  String get entryListRowOpenHint =>
      'Double tap to open. Swipe right to delete.';

  @override
  String get entryListRowDraftBadge => 'draft';

  @override
  String get entryListRowDraftValue => 'draft';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'draft, $description';
  }

  @override
  String get entryDetailSaving => 'Saving changes...';

  @override
  String get entryDetailSaveFailed => 'Could not save your changes.';

  @override
  String get entryDetailLoadFailed => 'Could not load this entry.';

  @override
  String get entryDetailEditSemanticsLabel => 'Edit entry text';

  @override
  String get entryDetailEditHint => 'Edit your entry';

  @override
  String get entryDetailTapToEditHint => 'Tap to edit entry';

  @override
  String get entryDetailBackSemanticsLabel => 'Back to entries';

  @override
  String get entryDetailBack => 'Back';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Finish editing';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Edit entry';

  @override
  String get entryDetailDone => 'Done';

  @override
  String get entryDetailEdit => 'Edit';

  @override
  String get entryDetailShareSemanticsLabel => 'Share entry';

  @override
  String get entryDetailShare => 'Share';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Delete entry';

  @override
  String get entryDetailDelete => 'Delete';

  @override
  String get entryDetailShareFailed => 'Could not share this entry.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Delete entry?';

  @override
  String get deleteDialogBody => 'This entry will be permanently removed.';

  @override
  String get deleteCancel => 'Cancel';

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get deleteCancelSemanticsLabel => 'Cancel deletion';

  @override
  String get deleteCancelSemanticsHint => 'Keeps this entry in the list.';

  @override
  String get deleteConfirmSemanticsLabel => 'Delete entry permanently';

  @override
  String get deleteConfirmSemanticsHint => 'Removes this entry from the list.';

  @override
  String get appLockTitle => 'wrait is locked';

  @override
  String get appLockSemanticsLabel => 'Wrait is locked.';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockOpenSettings => 'Open settings';

  @override
  String get appLockContinueWithout => 'Continue without lock';

  @override
  String get appLockStillLocked => 'still locked';

  @override
  String get appLockSetUpSecurity => 'set up device security to protect Wrait';

  @override
  String get appLockUnavailableTryAgain => 'unlock unavailable · try again';

  @override
  String get appLockUnlockToContinue => 'Unlock Wrait to continue.';

  @override
  String get appLockSettingsWarning =>
      'Your diary will be visible until you set up device security.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Double tap Unlock to authenticate and continue.';

  @override
  String get appLockSemanticsHintSettings =>
      'Double tap Unlock to try again, or open settings to configure device security.';

  @override
  String get appLockSemanticsHintAuthInProgress =>
      'Authentication is in progress.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait could not load your privacy setting.';

  @override
  String get appLockPreferenceLoading => 'loading privacy settings';

  @override
  String get appLockPreferenceRetry => 'Try again';

  @override
  String get feedbackTitle => 'send feedback';

  @override
  String get feedbackPrompt => 'What would you like to share?';

  @override
  String get feedbackContactLabel => 'reply contact (optional)';

  @override
  String get feedbackContactHint => 'any contact information';

  @override
  String get feedbackMessageLabel => 'feedback';

  @override
  String get feedbackMessageHint => 'what would you like to share?';

  @override
  String get feedbackPrivacyCopy =>
      'Do not include private journal content unless you choose to type it into your message.';

  @override
  String get feedbackCancel => 'cancel';

  @override
  String get feedbackSubmit => 'submit';

  @override
  String get feedbackDismissLabel => 'Dismiss feedback';

  @override
  String get feedbackCategoryBug => 'Bug';

  @override
  String get feedbackCategoryIdea => 'Idea';

  @override
  String get feedbackCategoryConfusing => 'Confusing';

  @override
  String get feedbackCategoryPraise => 'Praise';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsManage => 'Manage tags';

  @override
  String get tagsAdd => 'Add tag';

  @override
  String get tagsAddHint => 'Tag name';

  @override
  String get tagsEmpty => 'No tags yet';

  @override
  String tagsLimitReached(int max) {
    return 'Tag limit reached ($max)';
  }

  @override
  String get tagsDeleteConfirmTitle => 'Delete tag?';

  @override
  String get tagsDeleteConfirmBody =>
      'This tag will be removed from all entries.';

  @override
  String get tagsDeleteConfirm => 'Delete';

  @override
  String get tagsDeleteCancel => 'Cancel';

  @override
  String tagsNameTooLong(int max) {
    return 'Tag name must be $max characters or fewer';
  }

  @override
  String get tagsNameDuplicate => 'This tag already exists';

  @override
  String get tagsCreateFailed => 'Could not create tag';

  @override
  String get tagsDeleteFailed => 'Could not delete tag';

  @override
  String get tagsFilterAll => 'All';

  @override
  String get tagsFilterClear => 'Clear filter';

  @override
  String get tagsNoEntriesWithTag => 'No entries with this tag';

  @override
  String get tagsAssign => 'Tags';

  @override
  String get tagsAssignDone => 'Done';

  @override
  String tagsAssignCreate(String name) {
    return 'Create \"$name\"';
  }

  @override
  String tagsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get tagsSearchIncluded => 'Search includes tag names';
}
