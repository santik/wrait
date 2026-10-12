// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get bootstrapTitle => 'открываем wrait';

  @override
  String get bootstrapSubtitle => 'загрузка локального дневника';

  @override
  String get bootstrapErrorTitle => 'не удалось открыть wrait';

  @override
  String get bootstrapErrorSubtitle => 'попробуйте снова';

  @override
  String get bootstrapRetryButton => 'повторить';

  @override
  String get mainSettingsTooltip => 'Настройки';

  @override
  String get mainFeedbackTooltip => 'Отправить отзыв';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Язык: $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Язык недоступен · попробуйте снова';

  @override
  String get mainFeedbackSent => 'отзыв отправлен';

  @override
  String get mainFeedbackUnavailable => 'отзыв сейчас недоступен';

  @override
  String get mainFeedbackFailed =>
      'не удалось отправить отзыв. попробуйте снова';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Выбранный язык транскрипции $displayName. Открывает настройки языка.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Настройки';

  @override
  String get mainFeedbackSemanticsLabel => 'Отправить отзыв';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Квота записей: $limit всего, $remaining осталось.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '$limit всего / $remaining осталось';
  }

  @override
  String get mainButtonStop => 'стоп';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'нажмите кнопку для записи';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'слушаю...';

  @override
  String get statusProcessing => 'обработка...';

  @override
  String get statusCleaningUp => 'редактирование...';

  @override
  String get statusSavedTapToRead => 'сохранено, нажмите для чтения';

  @override
  String get statusDeleted => 'удалено';

  @override
  String get statusNoConnectionDraft =>
      'нет соединения · сохранено как черновик';

  @override
  String get statusServiceUnavailableDraft =>
      'сервис недоступен · сохранено как черновик';

  @override
  String get statusServerConfigErrorDraft =>
      'ошибка конфигурации сервера · сохранено как черновик';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'не распознано · сохранено как черновик';

  @override
  String get statusSpeechNotRecognized => 'не распознано';

  @override
  String get statusApiFailedDraft => 'сохранено как черновик · повтор позже';

  @override
  String get statusTooShort => 'слишком коротко · продолжайте говорить';

  @override
  String get statusNothingCaught => 'ничего не уловлено · слишком тихо?';

  @override
  String get statusMicNeeded => 'нужен микрофон · нажмите снова';

  @override
  String get statusMicBlocked => 'микрофон заблокирован · откройте настройки';

  @override
  String get statusNoConnection => 'нет соединения';

  @override
  String get statusServiceUnavailable => 'сервис недоступен';

  @override
  String get statusServerConfigError => 'ошибка конфигурации сервера';

  @override
  String get statusSomethingWentWrong => 'что-то пошло не так';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Для начала записи необходим доступ к микрофону.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Нажмите дважды, чтобы запросить доступ к микрофону снова.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'Доступ к микрофону заблокирован для Wrait.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Нажмите дважды, чтобы открыть настройки приложения.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Статус: $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count записи',
      many: '$count записей',
      few: '$count записи',
      one: '$count запись',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Статистика записей: $displayText. Открывает список записей.';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsBack => 'Назад';

  @override
  String get settingsPrivacy => 'Конфиденциальность';

  @override
  String get settingsAppLock => 'Блокировка приложения';

  @override
  String get settingsAppLockDescription =>
      'Используйте блокировку экрана устройства при открытии или возврате в Wrait.';

  @override
  String get settingsAppLockUnavailable =>
      'Блокировка приложения недоступна в этой тестовой сборке.';

  @override
  String get settingsAppLockNoSecurity =>
      'Настройте блокировку экрана устройства перед включением блокировки приложения.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'Аутентификация устройства временно недоступна. Попробуйте снова.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'Аутентификация устройства недоступна на этом устройстве.';

  @override
  String get settingsAppLockSaveFailed =>
      'Не удалось сохранить настройку блокировки. Попробуйте снова.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Не удалось открыть настройки безопасности устройства.';

  @override
  String get settingsOpenDeviceSettings => 'Открыть настройки устройства';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'Системная';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsThemeSaveFailed =>
      'Не удалось сохранить тему. Попробуйте снова.';

  @override
  String get settingsTranscriptionLanguage => 'Язык транскрипции';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Выберите язык, на котором вы говорите, чтобы улучшить транскрипцию. Автоматическое определение используется, когда язык не выбран.';

  @override
  String get settingsAutomaticDetection => 'Автоматическое определение';

  @override
  String get settingsLoading => 'Загрузка…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Не удалось загрузить язык транскрипции.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Не удалось сохранить язык. Попробуйте снова.';

  @override
  String get settingsTryAgain => 'Попробовать снова';

  @override
  String get settingsActivityMessage =>
      'Завершите текущую запись или транскрипцию перед изменением настроек.';

  @override
  String get entryListBack => 'Назад';

  @override
  String get entryListBackSemanticsLabel => 'Назад на главный экран';

  @override
  String get entryListSearchLabel => 'Поиск записей';

  @override
  String get entryListClearSearch => 'Очистить поиск';

  @override
  String get entryListImportCsv => 'Импорт CSV';

  @override
  String get entryListExportCsv => 'Экспорт CSV';

  @override
  String get entryListImporting => 'Импорт CSV';

  @override
  String get entryListExporting => 'Экспорт CSV';

  @override
  String get entryListImportingSemanticsLabel => 'Импорт записей';

  @override
  String get entryListExportingSemanticsLabel => 'Экспорт записей';

  @override
  String get entryListImportSemanticsLabel => 'Импортировать записи';

  @override
  String get entryListExportSemanticsLabel => 'Экспортировать записи';

  @override
  String get entryListEmpty => 'записей пока нет';

  @override
  String get entryListNoResults => 'Записи не найдены';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return 'Экспортировано $fileName в $pathLabel.';
  }

  @override
  String get entryListExportFailed => 'Не удалось экспортировать записи.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'записей',
      many: 'записей',
      few: 'записи',
      one: 'запись',
    );
    return 'Импортировано $count $_temp0 из $fileName.';
  }

  @override
  String get entryListImportFailed => 'Не удалось импортировать записи.';

  @override
  String get entryListImportInvalidFormat =>
      'Выбранный CSV не является экспортом Wrait.';

  @override
  String get entryListImportUnreadableFile =>
      'Не удалось прочитать выбранный CSV-файл.';

  @override
  String get entryListImportFileTooLarge =>
      'Выбранный CSV слишком велик для импорта.';

  @override
  String get entryListImportStorageFailure =>
      'Не удалось сохранить импортированные записи.';

  @override
  String get entryListAudioDraftPreview => 'ожидание · повтор позже';

  @override
  String get entryListAudioDraftStateDescription =>
      'Аудио-черновик, ещё не транскрибирован';

  @override
  String get entryListDeleteActionLabel => 'Удалить запись';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Запись $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Проведите вправо для удаления.';

  @override
  String get entryListRowOpenHint =>
      'Нажмите дважды, чтобы открыть. Проведите вправо для удаления.';

  @override
  String get entryListRowDraftBadge => 'черновик';

  @override
  String get entryListRowDraftValue => 'черновик';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'черновик, $description';
  }

  @override
  String get entryDetailSaving => 'Сохранение изменений...';

  @override
  String get entryDetailSaveFailed => 'Не удалось сохранить изменения.';

  @override
  String get entryDetailLoadFailed => 'Не удалось загрузить эту запись.';

  @override
  String get entryDetailEditSemanticsLabel => 'Редактировать текст записи';

  @override
  String get entryDetailEditHint => 'Редактировать запись';

  @override
  String get entryDetailTapToEditHint => 'Нажмите для редактирования записи';

  @override
  String get entryDetailBackSemanticsLabel => 'Назад к записям';

  @override
  String get entryDetailBack => 'Назад';

  @override
  String get entryDetailFinishEditingSemanticsLabel =>
      'Завершить редактирование';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Редактировать запись';

  @override
  String get entryDetailDone => 'Готово';

  @override
  String get entryDetailEdit => 'Изменить';

  @override
  String get entryDetailShareSemanticsLabel => 'Поделиться записью';

  @override
  String get entryDetailShare => 'Поделиться';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Удалить запись';

  @override
  String get entryDetailDelete => 'Удалить';

  @override
  String get entryDetailShareFailed => 'Не удалось поделиться записью.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count слов',
      many: '$count слов',
      few: '$count слова',
      one: '$count слово',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Удалить запись?';

  @override
  String get deleteDialogBody => 'Эта запись будет удалена навсегда.';

  @override
  String get deleteCancel => 'Отмена';

  @override
  String get deleteConfirm => 'Удалить';

  @override
  String get deleteCancelSemanticsLabel => 'Отменить удаление';

  @override
  String get deleteCancelSemanticsHint => 'Сохраняет запись в списке.';

  @override
  String get deleteConfirmSemanticsLabel => 'Удалить запись навсегда';

  @override
  String get deleteConfirmSemanticsHint => 'Убирает запись из списка.';

  @override
  String get appLockTitle => 'wrait заблокирован';

  @override
  String get appLockSemanticsLabel => 'Wrait заблокирован.';

  @override
  String get appLockUnlock => 'Разблокировать';

  @override
  String get appLockOpenSettings => 'Открыть настройки';

  @override
  String get appLockContinueWithout => 'Продолжить без блокировки';

  @override
  String get appLockStillLocked => 'всё ещё заблокировано';

  @override
  String get appLockSetUpSecurity =>
      'настройте защиту устройства для защиты Wrait';

  @override
  String get appLockUnavailableTryAgain =>
      'разблокировка недоступна · попробуйте снова';

  @override
  String get appLockUnlockToContinue =>
      'Разблокируйте Wrait, чтобы продолжить.';

  @override
  String get appLockSettingsWarning =>
      'Ваш дневник будет виден, пока вы не настроите защиту устройства.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Нажмите дважды Разблокировать для аутентификации и продолжения.';

  @override
  String get appLockSemanticsHintSettings =>
      'Нажмите дважды Разблокировать, чтобы попробовать снова, или откройте настройки для настройки защиты устройства.';

  @override
  String get appLockSemanticsHintAuthInProgress => 'Аутентификация в процессе.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait не удалось загрузить настройку приватности.';

  @override
  String get appLockPreferenceLoading => 'загрузка настроек приватности';

  @override
  String get appLockPreferenceRetry => 'Повторить';

  @override
  String get feedbackTitle => 'отправить отзыв';

  @override
  String get feedbackPrompt => 'Чем хотите поделиться?';

  @override
  String get feedbackContactLabel => 'контакт для ответа (необязательно)';

  @override
  String get feedbackContactHint => 'любая контактная информация';

  @override
  String get feedbackMessageLabel => 'отзыв';

  @override
  String get feedbackMessageHint => 'чем хотите поделиться?';

  @override
  String get feedbackPrivacyCopy =>
      'Не включайте содержимое дневника, если вы не решите напечатать его в своём сообщении.';

  @override
  String get feedbackCancel => 'отмена';

  @override
  String get feedbackSubmit => 'отправить';

  @override
  String get feedbackDismissLabel => 'Закрыть форму отзыва';

  @override
  String get feedbackCategoryBug => 'Ошибка';

  @override
  String get feedbackCategoryIdea => 'Идея';

  @override
  String get feedbackCategoryConfusing => 'Непонятно';

  @override
  String get feedbackCategoryPraise => 'Похвала';
}
