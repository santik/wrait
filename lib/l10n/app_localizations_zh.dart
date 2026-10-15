// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get bootstrapTitle => '正在打开 wrait';

  @override
  String get bootstrapSubtitle => '正在加载你的本地日记';

  @override
  String get bootstrapErrorTitle => '无法打开 wrait';

  @override
  String get bootstrapErrorSubtitle => '请重试';

  @override
  String get bootstrapRetryButton => '重试';

  @override
  String get mainSettingsTooltip => '设置';

  @override
  String get mainFeedbackTooltip => '发送反馈';

  @override
  String mainLanguageLabel(String displayName) {
    return '语言：$displayName';
  }

  @override
  String get mainLanguageUnavailable => '语言不可用 · 请重试';

  @override
  String get mainFeedbackSent => '反馈已发送';

  @override
  String get mainFeedbackUnavailable => '暂时无法使用反馈功能';

  @override
  String get mainFeedbackFailed => '反馈发送失败，请重试';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return '当前转写语言为$displayName。打开转写语言设置。';
  }

  @override
  String get mainSettingsSemanticsLabel => '设置';

  @override
  String get mainFeedbackSemanticsLabel => '发送反馈';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return '录音额度共 $limit，剩余 $remaining。';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '共 $limit / 剩余 $remaining';
  }

  @override
  String get mainButtonStop => '停止';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => '点按按钮开始书写';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => '聆听中...';

  @override
  String get statusProcessing => '处理中...';

  @override
  String get statusCleaningUp => '整理中...';

  @override
  String get statusSavedTapToRead => '已保存，点按查看';

  @override
  String get statusDeleted => '已删除';

  @override
  String get statusNoConnectionDraft => '无网络连接 · 已存为草稿';

  @override
  String get statusServiceUnavailableDraft => '服务不可用 · 已存为草稿';

  @override
  String get statusServerConfigErrorDraft => '服务器配置错误 · 已存为草稿';

  @override
  String get statusSpeechNotRecognizedDraft => '未能识别 · 已存为草稿';

  @override
  String get statusSpeechNotRecognized => '未能识别';

  @override
  String get statusApiFailedDraft => '已存为草稿 · 稍后重试';

  @override
  String get statusTooShort => '太短了 · 请继续说';

  @override
  String get statusNothingCaught => '没有听到内容 · 声音太小？';

  @override
  String get statusMicNeeded => '需要麦克风权限 · 请再次点按';

  @override
  String get statusMicBlocked => '麦克风已被禁用 · 点按前往设置';

  @override
  String get statusNoConnection => '无网络连接';

  @override
  String get statusServiceUnavailable => '服务不可用';

  @override
  String get statusServerConfigError => '服务器配置错误';

  @override
  String get statusSomethingWentWrong => '出了点问题';

  @override
  String get statusMicNeededSemanticsLabel => '开始录音需要麦克风权限。';

  @override
  String get statusMicNeededSemanticsHint => '双击以再次请求麦克风权限。';

  @override
  String get statusMicBlockedSemanticsLabel => 'Wrait 的麦克风权限已被禁用。';

  @override
  String get statusMicBlockedSemanticsHint => '双击以打开应用设置。';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return '状态消息：$statusText。';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return '日记统计：$displayText。打开日记列表。';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsBack => '返回';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsAppLock => '应用锁';

  @override
  String get settingsAppLockDescription => '打开或返回 Wrait 时，使用设备的锁屏方式进行验证。';

  @override
  String get settingsAppLockUnavailable => '此验证版本不支持应用锁。';

  @override
  String get settingsAppLockNoSecurity => '启用应用锁前，请先设置设备锁屏。';

  @override
  String get settingsAppLockTemporarilyUnavailable => '设备身份验证暂时不可用，请重试。';

  @override
  String get settingsAppLockUnavailableDevice => '此设备不支持设备身份验证。';

  @override
  String get settingsAppLockSaveFailed => '无法保存应用锁设置，请重试。';

  @override
  String get settingsAppLockSettingsFailed => '无法打开设备安全设置。';

  @override
  String get settingsOpenDeviceSettings => '打开设备设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeSaveFailed => '无法保存主题，请重试。';

  @override
  String get settingsReminders => '提醒';

  @override
  String get settingsRemindersToggle => '每日提醒';

  @override
  String get settingsRemindersDescription => '在早晨和傍晚收到写日记的提醒';

  @override
  String get settingsRemindersPermissionDenied => '提醒功能需要通知权限，请在设备设置中开启。';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => '用一段反思开始新的一天';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => '今天还有剩余的录音次数';

  @override
  String get settingsTranscriptionLanguage => '转写语言';

  @override
  String get settingsTranscriptionLanguageDescription =>
      '选择你说话使用的语言以提升转写效果。未选择语言时将自动检测。';

  @override
  String get settingsAutomaticDetection => '自动检测';

  @override
  String get settingsLoading => '加载中…';

  @override
  String get settingsTranscriptionLanguageLoadFailed => '无法加载转写语言。';

  @override
  String get settingsTranscriptionLanguageSaveFailed => '无法保存语言，请重试。';

  @override
  String get settingsTryAgain => '重试';

  @override
  String get settingsActivityMessage => '请先完成当前的录音或转写，再更改设置。';

  @override
  String get entryListBack => '返回';

  @override
  String get entryListBackSemanticsLabel => '返回主界面';

  @override
  String get entryListSearchLabel => '搜索日记';

  @override
  String get entryListClearSearch => '清除搜索';

  @override
  String get entryListImportCsv => '导入 CSV';

  @override
  String get entryListExportCsv => '导出 CSV';

  @override
  String get entryListImporting => '正在导入 CSV';

  @override
  String get entryListExporting => '正在导出 CSV';

  @override
  String get entryListImportingSemanticsLabel => '正在导入日记';

  @override
  String get entryListExportingSemanticsLabel => '正在导出日记';

  @override
  String get entryListImportSemanticsLabel => '导入日记';

  @override
  String get entryListExportSemanticsLabel => '导出日记';

  @override
  String get entryListEmpty => '还没有日记';

  @override
  String get entryListNoResults => '没有匹配的日记';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '已将 $fileName 导出到 $pathLabel。';
  }

  @override
  String get entryListExportFailed => '无法导出日记。';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条记录',
    );
    return '已从 $fileName 导入 $_temp0。';
  }

  @override
  String get entryListImportFailed => '无法导入日记。';

  @override
  String get entryListImportInvalidFormat => '所选 CSV 不是有效的 Wrait 导出文件。';

  @override
  String get entryListImportUnreadableFile => '无法读取所选的 CSV 文件。';

  @override
  String get entryListImportFileTooLarge => '所选 CSV 文件过大，无法导入。';

  @override
  String get entryListImportStorageFailure => '无法保存导入的日记。';

  @override
  String get entryListAudioDraftPreview => '待处理 · 稍后重试';

  @override
  String get entryListAudioDraftStateDescription => '音频草稿，尚未转写';

  @override
  String get entryListDeleteActionLabel => '删除日记';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return '日记 $timestamp。$languageLabel。';
  }

  @override
  String get entryListRowSwipeHint => '向右滑动可删除。';

  @override
  String get entryListRowOpenHint => '双击打开。向右滑动可删除。';

  @override
  String get entryListRowDraftBadge => '草稿';

  @override
  String get entryListRowDraftValue => '草稿';

  @override
  String entryListRowAudioDraftValue(String description) {
    return '草稿，$description';
  }

  @override
  String get entryDetailSaving => '正在保存更改...';

  @override
  String get entryDetailSaveFailed => '无法保存你的更改。';

  @override
  String get entryDetailLoadFailed => '无法加载这条日记。';

  @override
  String get entryDetailEditSemanticsLabel => '编辑日记文字';

  @override
  String get entryDetailEditHint => '编辑你的日记';

  @override
  String get entryDetailTapToEditHint => '点按以编辑日记';

  @override
  String get entryDetailBackSemanticsLabel => '返回日记列表';

  @override
  String get entryDetailBack => '返回';

  @override
  String get entryDetailFinishEditingSemanticsLabel => '完成编辑';

  @override
  String get entryDetailEditEntrySemanticsLabel => '编辑日记';

  @override
  String get entryDetailDone => '完成';

  @override
  String get entryDetailEdit => '编辑';

  @override
  String get entryDetailShareSemanticsLabel => '分享日记';

  @override
  String get entryDetailShare => '分享';

  @override
  String get entryDetailDeleteSemanticsLabel => '删除日记';

  @override
  String get entryDetailDelete => '删除';

  @override
  String get entryDetailShareFailed => '无法分享这条日记。';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 字',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => '删除这条日记？';

  @override
  String get deleteDialogBody => '这条日记将被永久删除。';

  @override
  String get deleteCancel => '取消';

  @override
  String get deleteConfirm => '删除';

  @override
  String get deleteCancelSemanticsLabel => '取消删除';

  @override
  String get deleteCancelSemanticsHint => '将这条日记保留在列表中。';

  @override
  String get deleteConfirmSemanticsLabel => '永久删除日记';

  @override
  String get deleteConfirmSemanticsHint => '从列表中移除这条日记。';

  @override
  String get appLockTitle => 'wrait 已锁定';

  @override
  String get appLockSemanticsLabel => 'Wrait 已锁定。';

  @override
  String get appLockUnlock => '解锁';

  @override
  String get appLockOpenSettings => '打开设置';

  @override
  String get appLockContinueWithout => '不使用锁定，继续';

  @override
  String get appLockStillLocked => '仍处于锁定状态';

  @override
  String get appLockSetUpSecurity => '请设置设备安全方式以保护 Wrait';

  @override
  String get appLockUnavailableTryAgain => '无法解锁 · 请重试';

  @override
  String get appLockUnlockToContinue => '请解锁 Wrait 以继续。';

  @override
  String get appLockSettingsWarning => '在你设置设备安全方式之前，你的日记将可被任何人查看。';

  @override
  String get appLockSemanticsHintUnlock => '双击“解锁”进行验证并继续。';

  @override
  String get appLockSemanticsHintSettings => '双击“解锁”重试，或打开设置来配置设备安全方式。';

  @override
  String get appLockSemanticsHintAuthInProgress => '正在验证身份。';

  @override
  String get appLockPreferenceLoadFailed => 'Wrait 无法加载你的隐私设置。';

  @override
  String get appLockPreferenceLoading => '正在加载隐私设置';

  @override
  String get appLockPreferenceRetry => '重试';

  @override
  String get feedbackTitle => '发送反馈';

  @override
  String get feedbackPrompt => '你想分享些什么？';

  @override
  String get feedbackContactLabel => '回复联系方式（可选）';

  @override
  String get feedbackContactHint => '任意联系方式';

  @override
  String get feedbackMessageLabel => '反馈';

  @override
  String get feedbackMessageHint => '你想分享些什么？';

  @override
  String get feedbackPrivacyCopy => '请勿包含私人日记内容，除非你自己选择将其输入到消息中。';

  @override
  String get feedbackCancel => '取消';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackDismissLabel => '关闭反馈';

  @override
  String get feedbackCategoryBug => '问题';

  @override
  String get feedbackCategoryIdea => '建议';

  @override
  String get feedbackCategoryConfusing => '困惑';

  @override
  String get feedbackCategoryPraise => '好评';
}
