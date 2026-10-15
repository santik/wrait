import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('es', '419'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @bootstrapTitle.
  ///
  /// In en, this message translates to:
  /// **'opening wrait'**
  String get bootstrapTitle;

  /// No description provided for @bootstrapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'loading your local journal'**
  String get bootstrapSubtitle;

  /// No description provided for @bootstrapErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'could not open wrait'**
  String get bootstrapErrorTitle;

  /// No description provided for @bootstrapErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'try again'**
  String get bootstrapErrorSubtitle;

  /// No description provided for @bootstrapRetryButton.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get bootstrapRetryButton;

  /// No description provided for @mainSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mainSettingsTooltip;

  /// No description provided for @mainFeedbackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get mainFeedbackTooltip;

  /// No description provided for @mainLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language: {displayName}'**
  String mainLanguageLabel(String displayName);

  /// No description provided for @mainLanguageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Language unavailable · try again'**
  String get mainLanguageUnavailable;

  /// No description provided for @mainFeedbackSent.
  ///
  /// In en, this message translates to:
  /// **'feedback sent'**
  String get mainFeedbackSent;

  /// No description provided for @mainFeedbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'feedback is unavailable right now'**
  String get mainFeedbackUnavailable;

  /// No description provided for @mainFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'feedback could not be sent. try again'**
  String get mainFeedbackFailed;

  /// No description provided for @mainLanguageSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected transcription language {displayName}. Opens transcription language settings.'**
  String mainLanguageSemanticsLabel(String displayName);

  /// No description provided for @mainSettingsSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get mainSettingsSemanticsLabel;

  /// No description provided for @mainFeedbackSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get mainFeedbackSemanticsLabel;

  /// No description provided for @mainQuotaSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recording quota {limit} total and {remaining} left.'**
  String mainQuotaSemanticsLabel(int limit, int remaining);

  /// No description provided for @mainQuotaText.
  ///
  /// In en, this message translates to:
  /// **'{limit} total / {remaining} left'**
  String mainQuotaText(int limit, int remaining);

  /// No description provided for @mainButtonStop.
  ///
  /// In en, this message translates to:
  /// **'stop'**
  String get mainButtonStop;

  /// No description provided for @mainButtonWrait.
  ///
  /// In en, this message translates to:
  /// **'wrait'**
  String get mainButtonWrait;

  /// No description provided for @statusTapToWrite.
  ///
  /// In en, this message translates to:
  /// **'tap button to write'**
  String get statusTapToWrite;

  /// No description provided for @statusWrait.
  ///
  /// In en, this message translates to:
  /// **'wrait'**
  String get statusWrait;

  /// No description provided for @statusListening.
  ///
  /// In en, this message translates to:
  /// **'listening...'**
  String get statusListening;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'processing...'**
  String get statusProcessing;

  /// No description provided for @statusCleaningUp.
  ///
  /// In en, this message translates to:
  /// **'cleaning up...'**
  String get statusCleaningUp;

  /// No description provided for @statusSavedTapToRead.
  ///
  /// In en, this message translates to:
  /// **'saved, tap to read'**
  String get statusSavedTapToRead;

  /// No description provided for @statusDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get statusDeleted;

  /// No description provided for @statusNoConnectionDraft.
  ///
  /// In en, this message translates to:
  /// **'no connection · saved as draft'**
  String get statusNoConnectionDraft;

  /// No description provided for @statusServiceUnavailableDraft.
  ///
  /// In en, this message translates to:
  /// **'service unavailable · saved as draft'**
  String get statusServiceUnavailableDraft;

  /// No description provided for @statusServerConfigErrorDraft.
  ///
  /// In en, this message translates to:
  /// **'server config error · saved as draft'**
  String get statusServerConfigErrorDraft;

  /// No description provided for @statusSpeechNotRecognizedDraft.
  ///
  /// In en, this message translates to:
  /// **'not recognized · saved as draft'**
  String get statusSpeechNotRecognizedDraft;

  /// No description provided for @statusSpeechNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'not recognized'**
  String get statusSpeechNotRecognized;

  /// No description provided for @statusApiFailedDraft.
  ///
  /// In en, this message translates to:
  /// **'saved as draft · will retry'**
  String get statusApiFailedDraft;

  /// No description provided for @statusTooShort.
  ///
  /// In en, this message translates to:
  /// **'too short · keep talking'**
  String get statusTooShort;

  /// No description provided for @statusNothingCaught.
  ///
  /// In en, this message translates to:
  /// **'nothing caught · too quiet?'**
  String get statusNothingCaught;

  /// No description provided for @statusMicNeeded.
  ///
  /// In en, this message translates to:
  /// **'mic needed · tap again'**
  String get statusMicNeeded;

  /// No description provided for @statusMicBlocked.
  ///
  /// In en, this message translates to:
  /// **'mic blocked · tap settings'**
  String get statusMicBlocked;

  /// No description provided for @statusNoConnection.
  ///
  /// In en, this message translates to:
  /// **'no connection'**
  String get statusNoConnection;

  /// No description provided for @statusServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'service unavailable'**
  String get statusServiceUnavailable;

  /// No description provided for @statusServerConfigError.
  ///
  /// In en, this message translates to:
  /// **'server config error'**
  String get statusServerConfigError;

  /// No description provided for @statusSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'something went wrong'**
  String get statusSomethingWentWrong;

  /// No description provided for @statusMicNeededSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required to start recording.'**
  String get statusMicNeededSemanticsLabel;

  /// No description provided for @statusMicNeededSemanticsHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to request microphone access again.'**
  String get statusMicNeededSemanticsHint;

  /// No description provided for @statusMicBlockedSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is blocked for Wrait.'**
  String get statusMicBlockedSemanticsLabel;

  /// No description provided for @statusMicBlockedSemanticsHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to open app settings.'**
  String get statusMicBlockedSemanticsHint;

  /// No description provided for @statusDefaultSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Status message {statusText}.'**
  String statusDefaultSemanticsLabel(String statusText);

  /// No description provided for @statsEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} entry} other{{count} entries}}'**
  String statsEntryCount(int count);

  /// No description provided for @statsActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day} other{{count} days}}'**
  String statsActiveDays(int count);

  /// No description provided for @statsDisplay.
  ///
  /// In en, this message translates to:
  /// **'{entries} - {days}'**
  String statsDisplay(String entries, String days);

  /// No description provided for @statsSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry stats {displayText}. Opens the entry list.'**
  String statsSemanticsLabel(String displayText);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get settingsBack;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your device\'s screen lock when you open or return to Wrait.'**
  String get settingsAppLockDescription;

  /// No description provided for @settingsAppLockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'App lock is unavailable in this validation build.'**
  String get settingsAppLockUnavailable;

  /// No description provided for @settingsAppLockNoSecurity.
  ///
  /// In en, this message translates to:
  /// **'Set up a device screen lock before enabling app lock.'**
  String get settingsAppLockNoSecurity;

  /// No description provided for @settingsAppLockTemporarilyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Device authentication is temporarily unavailable. Try again.'**
  String get settingsAppLockTemporarilyUnavailable;

  /// No description provided for @settingsAppLockUnavailableDevice.
  ///
  /// In en, this message translates to:
  /// **'Device authentication is unavailable on this device.'**
  String get settingsAppLockUnavailableDevice;

  /// No description provided for @settingsAppLockSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the app-lock setting. Try again.'**
  String get settingsAppLockSaveFailed;

  /// No description provided for @settingsAppLockSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open device security settings.'**
  String get settingsAppLockSettingsFailed;

  /// No description provided for @settingsOpenDeviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Open device settings'**
  String get settingsOpenDeviceSettings;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save theme. Try again.'**
  String get settingsThemeSaveFailed;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsRemindersToggle.
  ///
  /// In en, this message translates to:
  /// **'Daily reminders'**
  String get settingsRemindersToggle;

  /// No description provided for @settingsRemindersDescription.
  ///
  /// In en, this message translates to:
  /// **'Get reminded to journal in the morning and evening'**
  String get settingsRemindersDescription;

  /// No description provided for @settingsRemindersPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is required for reminders. Please enable it in your device settings.'**
  String get settingsRemindersPermissionDenied;

  /// No description provided for @reminderMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'wrait'**
  String get reminderMorningTitle;

  /// No description provided for @reminderMorningBody.
  ///
  /// In en, this message translates to:
  /// **'Start your day with a reflection'**
  String get reminderMorningBody;

  /// No description provided for @reminderEveningTitle.
  ///
  /// In en, this message translates to:
  /// **'wrait'**
  String get reminderEveningTitle;

  /// No description provided for @reminderEveningBody.
  ///
  /// In en, this message translates to:
  /// **'You still have recordings left today'**
  String get reminderEveningBody;

  /// No description provided for @settingsTranscriptionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Transcription language'**
  String get settingsTranscriptionLanguage;

  /// No description provided for @settingsTranscriptionLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language you speak to improve transcription. Automatic detection is used when no language is selected.'**
  String get settingsTranscriptionLanguageDescription;

  /// No description provided for @settingsAutomaticDetection.
  ///
  /// In en, this message translates to:
  /// **'Automatic detection'**
  String get settingsAutomaticDetection;

  /// No description provided for @settingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get settingsLoading;

  /// No description provided for @settingsTranscriptionLanguageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the transcription language.'**
  String get settingsTranscriptionLanguageLoadFailed;

  /// No description provided for @settingsTranscriptionLanguageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save language. Try again.'**
  String get settingsTranscriptionLanguageSaveFailed;

  /// No description provided for @settingsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get settingsTryAgain;

  /// No description provided for @settingsActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Finish the current recording or transcription before changing settings.'**
  String get settingsActivityMessage;

  /// No description provided for @entryListBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get entryListBack;

  /// No description provided for @entryListBackSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to main screen'**
  String get entryListBackSemanticsLabel;

  /// No description provided for @entryListSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search entries'**
  String get entryListSearchLabel;

  /// No description provided for @entryListClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get entryListClearSearch;

  /// No description provided for @entryListImportCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get entryListImportCsv;

  /// No description provided for @entryListExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get entryListExportCsv;

  /// No description provided for @entryListImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing CSV'**
  String get entryListImporting;

  /// No description provided for @entryListExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting CSV'**
  String get entryListExporting;

  /// No description provided for @entryListImportingSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Importing entries'**
  String get entryListImportingSemanticsLabel;

  /// No description provided for @entryListExportingSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Exporting entries'**
  String get entryListExportingSemanticsLabel;

  /// No description provided for @entryListImportSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Import entries'**
  String get entryListImportSemanticsLabel;

  /// No description provided for @entryListExportSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Export entries'**
  String get entryListExportSemanticsLabel;

  /// No description provided for @entryListEmpty.
  ///
  /// In en, this message translates to:
  /// **'no entries yet'**
  String get entryListEmpty;

  /// No description provided for @entryListNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching entries'**
  String get entryListNoResults;

  /// No description provided for @entryListExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported {fileName} to {pathLabel}.'**
  String entryListExportSuccess(String fileName, String pathLabel);

  /// No description provided for @entryListExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export entries.'**
  String get entryListExportFailed;

  /// No description provided for @entryListImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} {count, plural, =1{record} other{records}} from {fileName}.'**
  String entryListImportSuccess(int count, String fileName);

  /// No description provided for @entryListImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import entries.'**
  String get entryListImportFailed;

  /// No description provided for @entryListImportInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Selected CSV is not a valid Wrait export.'**
  String get entryListImportInvalidFormat;

  /// No description provided for @entryListImportUnreadableFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected CSV file.'**
  String get entryListImportUnreadableFile;

  /// No description provided for @entryListImportFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Selected CSV is too large to import.'**
  String get entryListImportFileTooLarge;

  /// No description provided for @entryListImportStorageFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not save imported entries.'**
  String get entryListImportStorageFailure;

  /// No description provided for @entryListAudioDraftPreview.
  ///
  /// In en, this message translates to:
  /// **'pending · will retry'**
  String get entryListAudioDraftPreview;

  /// No description provided for @entryListAudioDraftStateDescription.
  ///
  /// In en, this message translates to:
  /// **'Audio draft, not yet transcribed'**
  String get entryListAudioDraftStateDescription;

  /// No description provided for @entryListDeleteActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get entryListDeleteActionLabel;

  /// No description provided for @entryListRowSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry {timestamp}. {languageLabel}.'**
  String entryListRowSemanticsLabel(String timestamp, String languageLabel);

  /// No description provided for @entryListRowSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe right to delete.'**
  String get entryListRowSwipeHint;

  /// No description provided for @entryListRowOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to open. Swipe right to delete.'**
  String get entryListRowOpenHint;

  /// No description provided for @entryListRowDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get entryListRowDraftBadge;

  /// No description provided for @entryListRowDraftValue.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get entryListRowDraftValue;

  /// No description provided for @entryListRowAudioDraftValue.
  ///
  /// In en, this message translates to:
  /// **'draft, {description}'**
  String entryListRowAudioDraftValue(String description);

  /// No description provided for @entryDetailSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving changes...'**
  String get entryDetailSaving;

  /// No description provided for @entryDetailSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your changes.'**
  String get entryDetailSaveFailed;

  /// No description provided for @entryDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this entry.'**
  String get entryDetailLoadFailed;

  /// No description provided for @entryDetailEditSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit entry text'**
  String get entryDetailEditSemanticsLabel;

  /// No description provided for @entryDetailEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit your entry'**
  String get entryDetailEditHint;

  /// No description provided for @entryDetailTapToEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit entry'**
  String get entryDetailTapToEditHint;

  /// No description provided for @entryDetailBackSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to entries'**
  String get entryDetailBackSemanticsLabel;

  /// No description provided for @entryDetailBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get entryDetailBack;

  /// No description provided for @entryDetailFinishEditingSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish editing'**
  String get entryDetailFinishEditingSemanticsLabel;

  /// No description provided for @entryDetailEditEntrySemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get entryDetailEditEntrySemanticsLabel;

  /// No description provided for @entryDetailDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get entryDetailDone;

  /// No description provided for @entryDetailEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get entryDetailEdit;

  /// No description provided for @entryDetailShareSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Share entry'**
  String get entryDetailShareSemanticsLabel;

  /// No description provided for @entryDetailShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get entryDetailShare;

  /// No description provided for @entryDetailDeleteSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get entryDetailDeleteSemanticsLabel;

  /// No description provided for @entryDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get entryDetailDelete;

  /// No description provided for @entryDetailShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share this entry.'**
  String get entryDetailShareFailed;

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String wordCount(int count);

  /// No description provided for @deleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get deleteDialogTitle;

  /// No description provided for @deleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This entry will be permanently removed.'**
  String get deleteDialogBody;

  /// No description provided for @deleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteCancel;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConfirm;

  /// No description provided for @deleteCancelSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion'**
  String get deleteCancelSemanticsLabel;

  /// No description provided for @deleteCancelSemanticsHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps this entry in the list.'**
  String get deleteCancelSemanticsHint;

  /// No description provided for @deleteConfirmSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete entry permanently'**
  String get deleteConfirmSemanticsLabel;

  /// No description provided for @deleteConfirmSemanticsHint.
  ///
  /// In en, this message translates to:
  /// **'Removes this entry from the list.'**
  String get deleteConfirmSemanticsHint;

  /// No description provided for @appLockTitle.
  ///
  /// In en, this message translates to:
  /// **'wrait is locked'**
  String get appLockTitle;

  /// No description provided for @appLockSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Wrait is locked.'**
  String get appLockSemanticsLabel;

  /// No description provided for @appLockUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// No description provided for @appLockOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get appLockOpenSettings;

  /// No description provided for @appLockContinueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without lock'**
  String get appLockContinueWithout;

  /// No description provided for @appLockStillLocked.
  ///
  /// In en, this message translates to:
  /// **'still locked'**
  String get appLockStillLocked;

  /// No description provided for @appLockSetUpSecurity.
  ///
  /// In en, this message translates to:
  /// **'set up device security to protect Wrait'**
  String get appLockSetUpSecurity;

  /// No description provided for @appLockUnavailableTryAgain.
  ///
  /// In en, this message translates to:
  /// **'unlock unavailable · try again'**
  String get appLockUnavailableTryAgain;

  /// No description provided for @appLockUnlockToContinue.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wrait to continue.'**
  String get appLockUnlockToContinue;

  /// No description provided for @appLockSettingsWarning.
  ///
  /// In en, this message translates to:
  /// **'Your diary will be visible until you set up device security.'**
  String get appLockSettingsWarning;

  /// No description provided for @appLockSemanticsHintUnlock.
  ///
  /// In en, this message translates to:
  /// **'Double tap Unlock to authenticate and continue.'**
  String get appLockSemanticsHintUnlock;

  /// No description provided for @appLockSemanticsHintSettings.
  ///
  /// In en, this message translates to:
  /// **'Double tap Unlock to try again, or open settings to configure device security.'**
  String get appLockSemanticsHintSettings;

  /// No description provided for @appLockSemanticsHintAuthInProgress.
  ///
  /// In en, this message translates to:
  /// **'Authentication is in progress.'**
  String get appLockSemanticsHintAuthInProgress;

  /// No description provided for @appLockPreferenceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrait could not load your privacy setting.'**
  String get appLockPreferenceLoadFailed;

  /// No description provided for @appLockPreferenceLoading.
  ///
  /// In en, this message translates to:
  /// **'loading privacy settings'**
  String get appLockPreferenceLoading;

  /// No description provided for @appLockPreferenceRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get appLockPreferenceRetry;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'send feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to share?'**
  String get feedbackPrompt;

  /// No description provided for @feedbackContactLabel.
  ///
  /// In en, this message translates to:
  /// **'reply contact (optional)'**
  String get feedbackContactLabel;

  /// No description provided for @feedbackContactHint.
  ///
  /// In en, this message translates to:
  /// **'any contact information'**
  String get feedbackContactHint;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'feedback'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In en, this message translates to:
  /// **'what would you like to share?'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackPrivacyCopy.
  ///
  /// In en, this message translates to:
  /// **'Do not include private journal content unless you choose to type it into your message.'**
  String get feedbackPrivacyCopy;

  /// No description provided for @feedbackCancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get feedbackCancel;

  /// No description provided for @feedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'submit'**
  String get feedbackSubmit;

  /// No description provided for @feedbackDismissLabel.
  ///
  /// In en, this message translates to:
  /// **'Dismiss feedback'**
  String get feedbackDismissLabel;

  /// No description provided for @feedbackCategoryBug.
  ///
  /// In en, this message translates to:
  /// **'Bug'**
  String get feedbackCategoryBug;

  /// No description provided for @feedbackCategoryIdea.
  ///
  /// In en, this message translates to:
  /// **'Idea'**
  String get feedbackCategoryIdea;

  /// No description provided for @feedbackCategoryConfusing.
  ///
  /// In en, this message translates to:
  /// **'Confusing'**
  String get feedbackCategoryConfusing;

  /// No description provided for @feedbackCategoryPraise.
  ///
  /// In en, this message translates to:
  /// **'Praise'**
  String get feedbackCategoryPraise;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'ja',
    'ko',
    'pt',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case '419':
            return AppLocalizationsEs419();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
