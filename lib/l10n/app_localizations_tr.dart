// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get bootstrapTitle => 'wrait açılıyor';

  @override
  String get bootstrapSubtitle => 'yerel günlüğün yükleniyor';

  @override
  String get bootstrapErrorTitle => 'wrait açılamadı';

  @override
  String get bootstrapErrorSubtitle => 'tekrar dene';

  @override
  String get bootstrapRetryButton => 'tekrar dene';

  @override
  String get mainSettingsTooltip => 'Ayarlar';

  @override
  String get mainFeedbackTooltip => 'Geri bildirim gönder';

  @override
  String mainLanguageLabel(String displayName) {
    return 'Dil: $displayName';
  }

  @override
  String get mainLanguageUnavailable => 'Dil kullanılamıyor · tekrar dene';

  @override
  String get mainFeedbackSent => 'geri bildirim gönderildi';

  @override
  String get mainFeedbackUnavailable => 'geri bildirim şu anda kullanılamıyor';

  @override
  String get mainFeedbackFailed => 'geri bildirim gönderilemedi. tekrar dene';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return 'Seçili yazıya dökme dili $displayName. Yazıya dökme dili ayarlarını açar.';
  }

  @override
  String get mainSettingsSemanticsLabel => 'Ayarlar';

  @override
  String get mainFeedbackSemanticsLabel => 'Geri bildirim gönder';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return 'Kayıt kotası: toplam $limit, kalan $remaining.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return 'toplam $limit / kalan $remaining';
  }

  @override
  String get mainButtonStop => 'durdur';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'yazmak için düğmeye dokun';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => 'dinleniyor...';

  @override
  String get statusProcessing => 'işleniyor...';

  @override
  String get statusCleaningUp => 'düzenleniyor...';

  @override
  String get statusSavedTapToRead => 'kaydedildi, okumak için dokun';

  @override
  String get statusDeleted => 'silindi';

  @override
  String get statusNoConnectionDraft =>
      'bağlantı yok · taslak olarak kaydedildi';

  @override
  String get statusServiceUnavailableDraft =>
      'servis kullanılamıyor · taslak olarak kaydedildi';

  @override
  String get statusServerConfigErrorDraft =>
      'sunucu yapılandırma hatası · taslak olarak kaydedildi';

  @override
  String get statusSpeechNotRecognizedDraft =>
      'anlaşılamadı · taslak olarak kaydedildi';

  @override
  String get statusSpeechNotRecognized => 'anlaşılamadı';

  @override
  String get statusApiFailedDraft =>
      'taslak olarak kaydedildi · tekrar denenecek';

  @override
  String get statusTooShort => 'çok kısa · konuşmaya devam et';

  @override
  String get statusNothingCaught => 'hiçbir şey duyulmadı · çok mu sessiz?';

  @override
  String get statusMicNeeded => 'mikrofon gerekli · tekrar dokun';

  @override
  String get statusMicBlocked => 'mikrofon engelli · ayarlara dokun';

  @override
  String get statusNoConnection => 'bağlantı yok';

  @override
  String get statusServiceUnavailable => 'servis kullanılamıyor';

  @override
  String get statusServerConfigError => 'sunucu yapılandırma hatası';

  @override
  String get statusSomethingWentWrong => 'bir şeyler ters gitti';

  @override
  String get statusMicNeededSemanticsLabel =>
      'Kayda başlamak için mikrofon erişimi gerekli.';

  @override
  String get statusMicNeededSemanticsHint =>
      'Mikrofon erişimini yeniden istemek için çift dokunun.';

  @override
  String get statusMicBlockedSemanticsLabel =>
      'Wrait için mikrofon erişimi engellendi.';

  @override
  String get statusMicBlockedSemanticsHint =>
      'Uygulama ayarlarını açmak için çift dokunun.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'Durum mesajı: $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kayıt',
      one: '$count kayıt',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
      one: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'Kayıt istatistikleri: $displayText. Kayıt listesini açar.';
  }

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsBack => 'Geri';

  @override
  String get settingsPrivacy => 'Gizlilik';

  @override
  String get settingsAppLock => 'Uygulama kilidi';

  @override
  String get settingsAppLockDescription =>
      'Wrait\'i açtığında veya geri döndüğünde cihazının ekran kilidini kullan.';

  @override
  String get settingsAppLockUnavailable =>
      'Uygulama kilidi bu doğrulama sürümünde kullanılamıyor.';

  @override
  String get settingsAppLockNoSecurity =>
      'Uygulama kilidini etkinleştirmeden önce cihazında bir ekran kilidi ayarla.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      'Cihaz kimlik doğrulaması geçici olarak kullanılamıyor. Tekrar dene.';

  @override
  String get settingsAppLockUnavailableDevice =>
      'Bu cihazda cihaz kimlik doğrulaması kullanılamıyor.';

  @override
  String get settingsAppLockSaveFailed =>
      'Uygulama kilidi ayarı kaydedilemedi. Tekrar dene.';

  @override
  String get settingsAppLockSettingsFailed =>
      'Cihaz güvenlik ayarları açılamadı.';

  @override
  String get settingsOpenDeviceSettings => 'Cihaz ayarlarını aç';

  @override
  String get settingsTranscriptionLanguage => 'Yazıya dökme dili';

  @override
  String get settingsTranscriptionLanguageDescription =>
      'Yazıya dökme kalitesini artırmak için konuştuğun dili seç. Dil seçilmezse otomatik algılama kullanılır.';

  @override
  String get settingsAutomaticDetection => 'Otomatik algılama';

  @override
  String get settingsLoading => 'Yükleniyor…';

  @override
  String get settingsTranscriptionLanguageLoadFailed =>
      'Yazıya dökme dili yüklenemedi.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      'Dil kaydedilemedi. Tekrar dene.';

  @override
  String get settingsTryAgain => 'Tekrar dene';

  @override
  String get settingsActivityMessage =>
      'Ayarları değiştirmeden önce mevcut kaydı veya yazıya dökme işlemini tamamla.';

  @override
  String get entryListBack => 'Geri';

  @override
  String get entryListBackSemanticsLabel => 'Ana ekrana dön';

  @override
  String get entryListSearchLabel => 'Kayıtlarda ara';

  @override
  String get entryListClearSearch => 'Aramayı temizle';

  @override
  String get entryListImportCsv => 'CSV içe aktar';

  @override
  String get entryListExportCsv => 'CSV dışa aktar';

  @override
  String get entryListImporting => 'CSV içe aktarılıyor';

  @override
  String get entryListExporting => 'CSV dışa aktarılıyor';

  @override
  String get entryListImportingSemanticsLabel => 'Kayıtlar içe aktarılıyor';

  @override
  String get entryListExportingSemanticsLabel => 'Kayıtlar dışa aktarılıyor';

  @override
  String get entryListImportSemanticsLabel => 'Kayıtları içe aktar';

  @override
  String get entryListExportSemanticsLabel => 'Kayıtları dışa aktar';

  @override
  String get entryListEmpty => 'henüz kayıt yok';

  @override
  String get entryListNoResults => 'Eşleşen kayıt yok';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName dosyası $pathLabel konumuna aktarıldı.';
  }

  @override
  String get entryListExportFailed => 'Kayıtlar dışa aktarılamadı.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kayıt',
      one: 'kayıt',
    );
    return '$fileName dosyasından $count $_temp0 içe aktarıldı.';
  }

  @override
  String get entryListImportFailed => 'Kayıtlar içe aktarılamadı.';

  @override
  String get entryListImportInvalidFormat =>
      'Seçilen CSV geçerli bir Wrait dışa aktarımı değil.';

  @override
  String get entryListImportUnreadableFile => 'Seçilen CSV dosyası okunamadı.';

  @override
  String get entryListImportFileTooLarge =>
      'Seçilen CSV içe aktarılamayacak kadar büyük.';

  @override
  String get entryListImportStorageFailure =>
      'İçe aktarılan kayıtlar kaydedilemedi.';

  @override
  String get entryListAudioDraftPreview => 'bekliyor · tekrar denenecek';

  @override
  String get entryListAudioDraftStateDescription =>
      'Ses taslağı, henüz yazıya dökülmedi';

  @override
  String get entryListDeleteActionLabel => 'Kaydı sil';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'Kayıt $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => 'Silmek için sağa kaydırın.';

  @override
  String get entryListRowOpenHint =>
      'Açmak için çift dokunun. Silmek için sağa kaydırın.';

  @override
  String get entryListRowDraftBadge => 'taslak';

  @override
  String get entryListRowDraftValue => 'taslak';

  @override
  String entryListRowAudioDraftValue(String description) {
    return 'taslak, $description';
  }

  @override
  String get entryDetailSaving => 'Değişiklikler kaydediliyor...';

  @override
  String get entryDetailSaveFailed => 'Değişiklikler kaydedilemedi.';

  @override
  String get entryDetailLoadFailed => 'Bu kayıt yüklenemedi.';

  @override
  String get entryDetailEditSemanticsLabel => 'Kayıt metnini düzenle';

  @override
  String get entryDetailEditHint => 'Kaydını düzenle';

  @override
  String get entryDetailTapToEditHint => 'Kaydı düzenlemek için dokun';

  @override
  String get entryDetailBackSemanticsLabel => 'Kayıtlara dön';

  @override
  String get entryDetailBack => 'Geri';

  @override
  String get entryDetailFinishEditingSemanticsLabel => 'Düzenlemeyi bitir';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'Kaydı düzenle';

  @override
  String get entryDetailDone => 'Bitti';

  @override
  String get entryDetailEdit => 'Düzenle';

  @override
  String get entryDetailShareSemanticsLabel => 'Kaydı paylaş';

  @override
  String get entryDetailShare => 'Paylaş';

  @override
  String get entryDetailDeleteSemanticsLabel => 'Kaydı sil';

  @override
  String get entryDetailDelete => 'Sil';

  @override
  String get entryDetailShareFailed => 'Bu kayıt paylaşılamadı.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kelime',
      one: '1 kelime',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'Kayıt silinsin mi?';

  @override
  String get deleteDialogBody => 'Bu kayıt kalıcı olarak silinecek.';

  @override
  String get deleteCancel => 'İptal';

  @override
  String get deleteConfirm => 'Sil';

  @override
  String get deleteCancelSemanticsLabel => 'Silmeyi iptal et';

  @override
  String get deleteCancelSemanticsHint => 'Bu kaydı listede tutar.';

  @override
  String get deleteConfirmSemanticsLabel => 'Kaydı kalıcı olarak sil';

  @override
  String get deleteConfirmSemanticsHint => 'Bu kaydı listeden kaldırır.';

  @override
  String get appLockTitle => 'wrait kilitli';

  @override
  String get appLockSemanticsLabel => 'Wrait kilitli.';

  @override
  String get appLockUnlock => 'Kilidi aç';

  @override
  String get appLockOpenSettings => 'Ayarları aç';

  @override
  String get appLockContinueWithout => 'Kilitsiz devam et';

  @override
  String get appLockStillLocked => 'hâlâ kilitli';

  @override
  String get appLockSetUpSecurity =>
      'Wrait\'i korumak için cihaz güvenliğini ayarla';

  @override
  String get appLockUnavailableTryAgain =>
      'kilit açma kullanılamıyor · tekrar dene';

  @override
  String get appLockUnlockToContinue =>
      'Devam etmek için Wrait\'in kilidini aç.';

  @override
  String get appLockSettingsWarning =>
      'Cihaz güvenliğini ayarlayana kadar günlüğün herkes tarafından görülebilir.';

  @override
  String get appLockSemanticsHintUnlock =>
      'Kimlik doğrulayıp devam etmek için Kilidi aç düğmesine çift dokunun.';

  @override
  String get appLockSemanticsHintSettings =>
      'Tekrar denemek için Kilidi aç düğmesine çift dokunun veya cihaz güvenliğini yapılandırmak için ayarları açın.';

  @override
  String get appLockSemanticsHintAuthInProgress => 'Kimlik doğrulama sürüyor.';

  @override
  String get appLockPreferenceLoadFailed =>
      'Wrait gizlilik ayarını yükleyemedi.';

  @override
  String get appLockPreferenceLoading => 'gizlilik ayarları yükleniyor';

  @override
  String get appLockPreferenceRetry => 'Tekrar dene';

  @override
  String get feedbackTitle => 'geri bildirim gönder';

  @override
  String get feedbackPrompt => 'Ne paylaşmak istersin?';

  @override
  String get feedbackContactLabel => 'yanıt için iletişim (isteğe bağlı)';

  @override
  String get feedbackContactHint => 'herhangi bir iletişim bilgisi';

  @override
  String get feedbackMessageLabel => 'geri bildirim';

  @override
  String get feedbackMessageHint => 'ne paylaşmak istersin?';

  @override
  String get feedbackPrivacyCopy =>
      'Mesajına kendin yazmayı seçmediğin sürece özel günlük içeriğini ekleme.';

  @override
  String get feedbackCancel => 'iptal';

  @override
  String get feedbackSubmit => 'gönder';

  @override
  String get feedbackDismissLabel => 'Geri bildirimi kapat';

  @override
  String get feedbackCategoryBug => 'Hata';

  @override
  String get feedbackCategoryIdea => 'Fikir';

  @override
  String get feedbackCategoryConfusing => 'Kafa karıştırıcı';

  @override
  String get feedbackCategoryPraise => 'Övgü';
}
