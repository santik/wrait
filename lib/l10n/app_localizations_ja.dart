// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get bootstrapTitle => 'wrait を開いています';

  @override
  String get bootstrapSubtitle => 'ローカルの日記を読み込み中';

  @override
  String get bootstrapErrorTitle => 'wrait を開けませんでした';

  @override
  String get bootstrapErrorSubtitle => 'もう一度お試しください';

  @override
  String get bootstrapRetryButton => '再試行';

  @override
  String get mainSettingsTooltip => '設定';

  @override
  String get mainFeedbackTooltip => 'フィードバックを送信';

  @override
  String mainLanguageLabel(String displayName) {
    return '言語: $displayName';
  }

  @override
  String get mainLanguageUnavailable => '言語を利用できません · もう一度お試しください';

  @override
  String get mainFeedbackSent => 'フィードバックを送信しました';

  @override
  String get mainFeedbackUnavailable => '現在フィードバックを利用できません';

  @override
  String get mainFeedbackFailed => 'フィードバックを送信できませんでした。もう一度お試しください';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return '選択中の文字起こし言語は $displayName です。文字起こし言語の設定を開きます。';
  }

  @override
  String get mainSettingsSemanticsLabel => '設定';

  @override
  String get mainFeedbackSemanticsLabel => 'フィードバックを送信';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return '録音の上限は合計 $limit、残り $remaining です。';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '合計 $limit / 残り $remaining';
  }

  @override
  String get mainButtonStop => '停止';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => 'ボタンをタップして記録';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => '聞いています...';

  @override
  String get statusProcessing => '処理中...';

  @override
  String get statusCleaningUp => '整えています...';

  @override
  String get statusSavedTapToRead => '保存しました · タップして読む';

  @override
  String get statusDeleted => '削除しました';

  @override
  String get statusNoConnectionDraft => '接続なし · 下書きとして保存';

  @override
  String get statusServiceUnavailableDraft => 'サービス利用不可 · 下書きとして保存';

  @override
  String get statusServerConfigErrorDraft => 'サーバー設定エラー · 下書きとして保存';

  @override
  String get statusSpeechNotRecognizedDraft => '認識できず · 下書きとして保存';

  @override
  String get statusSpeechNotRecognized => '認識できませんでした';

  @override
  String get statusApiFailedDraft => '下書きとして保存 · 再試行します';

  @override
  String get statusTooShort => '短すぎます · もう少し話してください';

  @override
  String get statusNothingCaught => '聞き取れません · 声が小さい？';

  @override
  String get statusMicNeeded => 'マイクが必要です · もう一度タップ';

  @override
  String get statusMicBlocked => 'マイクがブロックされています · 設定をタップ';

  @override
  String get statusNoConnection => '接続なし';

  @override
  String get statusServiceUnavailable => 'サービス利用不可';

  @override
  String get statusServerConfigError => 'サーバー設定エラー';

  @override
  String get statusSomethingWentWrong => '問題が発生しました';

  @override
  String get statusMicNeededSemanticsLabel => '録音を開始するにはマイクへのアクセスが必要です。';

  @override
  String get statusMicNeededSemanticsHint => 'ダブルタップすると、マイクへのアクセスを再度リクエストします。';

  @override
  String get statusMicBlockedSemanticsLabel => 'wrait のマイクへのアクセスがブロックされています。';

  @override
  String get statusMicBlockedSemanticsHint => 'ダブルタップするとアプリの設定を開きます。';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return 'ステータスメッセージ: $statusText。';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return 'エントリーの統計: $displayText。エントリー一覧を開きます。';
  }

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsBack => '戻る';

  @override
  String get settingsPrivacy => 'プライバシー';

  @override
  String get settingsAppLock => 'アプリロック';

  @override
  String get settingsAppLockDescription => 'wrait を開くときや戻るときに、端末の画面ロックを使用します。';

  @override
  String get settingsAppLockUnavailable => 'この検証用ビルドではアプリロックを利用できません。';

  @override
  String get settingsAppLockNoSecurity => 'アプリロックを有効にする前に、端末の画面ロックを設定してください。';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      '端末認証を一時的に利用できません。もう一度お試しください。';

  @override
  String get settingsAppLockUnavailableDevice => 'この端末では端末認証を利用できません。';

  @override
  String get settingsAppLockSaveFailed => 'アプリロックの設定を保存できませんでした。もう一度お試しください。';

  @override
  String get settingsAppLockSettingsFailed => '端末のセキュリティ設定を開けませんでした。';

  @override
  String get settingsOpenDeviceSettings => '端末の設定を開く';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsThemeSystem => 'システム';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsThemeSaveFailed => 'テーマを保存できませんでした。もう一度お試しください。';

  @override
  String get settingsTranscriptionLanguage => '文字起こし言語';

  @override
  String get settingsTranscriptionLanguageDescription =>
      '話す言語を選ぶと、文字起こしの精度が向上します。言語を選択しない場合は自動検出が使われます。';

  @override
  String get settingsAutomaticDetection => '自動検出';

  @override
  String get settingsLoading => '読み込み中…';

  @override
  String get settingsTranscriptionLanguageLoadFailed => '文字起こし言語を読み込めませんでした。';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      '言語を保存できませんでした。もう一度お試しください。';

  @override
  String get settingsTryAgain => 'もう一度試す';

  @override
  String get settingsActivityMessage => '設定を変更する前に、現在の録音または文字起こしを完了してください。';

  @override
  String get entryListBack => '戻る';

  @override
  String get entryListBackSemanticsLabel => 'メイン画面に戻る';

  @override
  String get entryListSearchLabel => 'エントリーを検索';

  @override
  String get entryListClearSearch => '検索をクリア';

  @override
  String get entryListImportCsv => 'CSV をインポート';

  @override
  String get entryListExportCsv => 'CSV をエクスポート';

  @override
  String get entryListImporting => 'CSV をインポート中';

  @override
  String get entryListExporting => 'CSV をエクスポート中';

  @override
  String get entryListImportingSemanticsLabel => 'エントリーをインポート中';

  @override
  String get entryListExportingSemanticsLabel => 'エントリーをエクスポート中';

  @override
  String get entryListImportSemanticsLabel => 'エントリーをインポート';

  @override
  String get entryListExportSemanticsLabel => 'エントリーをエクスポート';

  @override
  String get entryListEmpty => 'エントリーはまだありません';

  @override
  String get entryListNoResults => '一致するエントリーはありません';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName を $pathLabel にエクスポートしました。';
  }

  @override
  String get entryListExportFailed => 'エントリーをエクスポートできませんでした。';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$fileName から $_temp0のレコードをインポートしました。';
  }

  @override
  String get entryListImportFailed => 'エントリーをインポートできませんでした。';

  @override
  String get entryListImportInvalidFormat =>
      '選択した CSV は wrait の有効なエクスポートファイルではありません。';

  @override
  String get entryListImportUnreadableFile => '選択した CSV ファイルを読み込めませんでした。';

  @override
  String get entryListImportFileTooLarge => '選択した CSV はサイズが大きすぎてインポートできません。';

  @override
  String get entryListImportStorageFailure => 'インポートしたエントリーを保存できませんでした。';

  @override
  String get entryListAudioDraftPreview => '保留中 · 再試行します';

  @override
  String get entryListAudioDraftStateDescription => '音声の下書き、まだ文字起こしされていません';

  @override
  String get entryListDeleteActionLabel => 'エントリーを削除';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return 'エントリー $timestamp。$languageLabel。';
  }

  @override
  String get entryListRowSwipeHint => '右にスワイプして削除します。';

  @override
  String get entryListRowOpenHint => 'ダブルタップで開きます。右にスワイプして削除します。';

  @override
  String get entryListRowDraftBadge => '下書き';

  @override
  String get entryListRowDraftValue => '下書き';

  @override
  String entryListRowAudioDraftValue(String description) {
    return '下書き、$description';
  }

  @override
  String get entryDetailSaving => '変更を保存中...';

  @override
  String get entryDetailSaveFailed => '変更を保存できませんでした。';

  @override
  String get entryDetailLoadFailed => 'このエントリーを読み込めませんでした。';

  @override
  String get entryDetailEditSemanticsLabel => 'エントリーのテキストを編集';

  @override
  String get entryDetailEditHint => 'エントリーを編集';

  @override
  String get entryDetailTapToEditHint => 'タップしてエントリーを編集';

  @override
  String get entryDetailBackSemanticsLabel => 'エントリー一覧に戻る';

  @override
  String get entryDetailBack => '戻る';

  @override
  String get entryDetailFinishEditingSemanticsLabel => '編集を完了';

  @override
  String get entryDetailEditEntrySemanticsLabel => 'エントリーを編集';

  @override
  String get entryDetailDone => '完了';

  @override
  String get entryDetailEdit => '編集';

  @override
  String get entryDetailShareSemanticsLabel => 'エントリーを共有';

  @override
  String get entryDetailShare => '共有';

  @override
  String get entryDetailDeleteSemanticsLabel => 'エントリーを削除';

  @override
  String get entryDetailDelete => '削除';

  @override
  String get entryDetailShareFailed => 'このエントリーを共有できませんでした。';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 語',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => 'エントリーを削除しますか？';

  @override
  String get deleteDialogBody => 'このエントリーは完全に削除されます。';

  @override
  String get deleteCancel => 'キャンセル';

  @override
  String get deleteConfirm => '削除';

  @override
  String get deleteCancelSemanticsLabel => '削除をキャンセル';

  @override
  String get deleteCancelSemanticsHint => 'このエントリーを一覧に残します。';

  @override
  String get deleteConfirmSemanticsLabel => 'エントリーを完全に削除';

  @override
  String get deleteConfirmSemanticsHint => 'このエントリーを一覧から削除します。';

  @override
  String get appLockTitle => 'wrait はロックされています';

  @override
  String get appLockSemanticsLabel => 'wrait はロックされています。';

  @override
  String get appLockUnlock => 'ロック解除';

  @override
  String get appLockOpenSettings => '設定を開く';

  @override
  String get appLockContinueWithout => 'ロックなしで続ける';

  @override
  String get appLockStillLocked => 'まだロックされています';

  @override
  String get appLockSetUpSecurity => 'wrait を保護するには端末のセキュリティを設定してください';

  @override
  String get appLockUnavailableTryAgain => 'ロック解除できません · もう一度お試しください';

  @override
  String get appLockUnlockToContinue => '続けるには wrait のロックを解除してください。';

  @override
  String get appLockSettingsWarning => '端末のセキュリティを設定するまで、日記は誰でも見られる状態です。';

  @override
  String get appLockSemanticsHintUnlock => '「ロック解除」をダブルタップして認証し、続行します。';

  @override
  String get appLockSemanticsHintSettings =>
      '「ロック解除」をダブルタップしてもう一度試すか、設定を開いて端末のセキュリティを設定してください。';

  @override
  String get appLockSemanticsHintAuthInProgress => '認証中です。';

  @override
  String get appLockPreferenceLoadFailed => 'wrait はプライバシー設定を読み込めませんでした。';

  @override
  String get appLockPreferenceLoading => 'プライバシー設定を読み込み中';

  @override
  String get appLockPreferenceRetry => 'もう一度試す';

  @override
  String get feedbackTitle => 'フィードバックを送信';

  @override
  String get feedbackPrompt => 'どのようなことをお伝えいただけますか？';

  @override
  String get feedbackContactLabel => '返信先の連絡先（任意）';

  @override
  String get feedbackContactHint => '連絡先情報';

  @override
  String get feedbackMessageLabel => 'フィードバック';

  @override
  String get feedbackMessageHint => 'お伝えしたいことを入力してください';

  @override
  String get feedbackPrivacyCopy => 'ご自身でメッセージに入力する場合を除き、日記の内容は含めないでください。';

  @override
  String get feedbackCancel => 'キャンセル';

  @override
  String get feedbackSubmit => '送信';

  @override
  String get feedbackDismissLabel => 'フィードバックを閉じる';

  @override
  String get feedbackCategoryBug => '不具合';

  @override
  String get feedbackCategoryIdea => 'アイデア';

  @override
  String get feedbackCategoryConfusing => 'わかりにくい';

  @override
  String get feedbackCategoryPraise => '良かった点';
}
