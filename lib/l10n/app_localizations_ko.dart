// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get bootstrapTitle => 'wrait 여는 중';

  @override
  String get bootstrapSubtitle => '내 기기의 일기를 불러오는 중';

  @override
  String get bootstrapErrorTitle => 'wrait을 열 수 없어요';

  @override
  String get bootstrapErrorSubtitle => '다시 시도해 주세요';

  @override
  String get bootstrapRetryButton => '다시 시도';

  @override
  String get mainSettingsTooltip => '설정';

  @override
  String get mainFeedbackTooltip => '의견 보내기';

  @override
  String mainLanguageLabel(String displayName) {
    return '언어: $displayName';
  }

  @override
  String get mainLanguageUnavailable => '언어를 사용할 수 없어요 · 다시 시도해 주세요';

  @override
  String get mainFeedbackSent => '의견을 보냈어요';

  @override
  String get mainFeedbackUnavailable => '지금은 의견을 보낼 수 없어요';

  @override
  String get mainFeedbackFailed => '의견을 보내지 못했어요. 다시 시도해 주세요';

  @override
  String mainLanguageSemanticsLabel(String displayName) {
    return '선택한 음성 인식 언어는 $displayName입니다. 음성 인식 언어 설정을 엽니다.';
  }

  @override
  String get mainSettingsSemanticsLabel => '설정';

  @override
  String get mainFeedbackSemanticsLabel => '의견 보내기';

  @override
  String mainQuotaSemanticsLabel(int limit, int remaining) {
    return '녹음 한도는 총 $limit이고 $remaining 남았습니다.';
  }

  @override
  String mainQuotaText(int limit, int remaining) {
    return '총 $limit / $remaining 남음';
  }

  @override
  String get mainButtonStop => '중지';

  @override
  String get mainButtonWrait => 'wrait';

  @override
  String get statusTapToWrite => '버튼을 눌러 기록하세요';

  @override
  String get statusWrait => 'wrait';

  @override
  String get statusListening => '듣는 중...';

  @override
  String get statusProcessing => '처리 중...';

  @override
  String get statusCleaningUp => '다듬는 중...';

  @override
  String get statusSavedTapToRead => '저장됨 · 눌러서 읽기';

  @override
  String get statusDeleted => '삭제됨';

  @override
  String get statusNoConnectionDraft => '연결 없음 · 임시 저장됨';

  @override
  String get statusServiceUnavailableDraft => '서비스 이용 불가 · 임시 저장됨';

  @override
  String get statusServerConfigErrorDraft => '서버 설정 오류 · 임시 저장됨';

  @override
  String get statusSpeechNotRecognizedDraft => '인식되지 않음 · 임시 저장됨';

  @override
  String get statusSpeechNotRecognized => '인식되지 않음';

  @override
  String get statusApiFailedDraft => '임시 저장됨 · 다시 시도할게요';

  @override
  String get statusTooShort => '너무 짧아요 · 계속 말해 주세요';

  @override
  String get statusNothingCaught => '들리는 게 없어요 · 너무 조용한가요?';

  @override
  String get statusMicNeeded => '마이크 필요 · 다시 눌러 주세요';

  @override
  String get statusMicBlocked => '마이크 차단됨 · 설정을 눌러 주세요';

  @override
  String get statusNoConnection => '연결 없음';

  @override
  String get statusServiceUnavailable => '서비스 이용 불가';

  @override
  String get statusServerConfigError => '서버 설정 오류';

  @override
  String get statusSomethingWentWrong => '문제가 발생했어요';

  @override
  String get statusMicNeededSemanticsLabel => '녹음을 시작하려면 마이크 접근 권한이 필요합니다.';

  @override
  String get statusMicNeededSemanticsHint => '두 번 탭하면 마이크 접근 권한을 다시 요청합니다.';

  @override
  String get statusMicBlockedSemanticsLabel => 'Wrait의 마이크 접근이 차단되어 있습니다.';

  @override
  String get statusMicBlockedSemanticsHint => '두 번 탭하면 앱 설정을 엽니다.';

  @override
  String statusDefaultSemanticsLabel(String statusText) {
    return '상태 메시지: $statusText.';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '기록 $count개',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일',
    );
    return '$_temp0';
  }

  @override
  String statsDisplay(String entries, String days) {
    return '$entries - $days';
  }

  @override
  String statsSemanticsLabel(String displayText) {
    return '기록 통계 $displayText. 기록 목록을 엽니다.';
  }

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsBack => '뒤로';

  @override
  String get settingsPrivacy => '개인정보 보호';

  @override
  String get settingsAppLock => '앱 잠금';

  @override
  String get settingsAppLockDescription =>
      'Wrait을 열거나 다시 돌아올 때 기기의 화면 잠금을 사용합니다.';

  @override
  String get settingsAppLockUnavailable => '이 검증 빌드에서는 앱 잠금을 사용할 수 없습니다.';

  @override
  String get settingsAppLockNoSecurity => '앱 잠금을 켜기 전에 기기 화면 잠금을 설정해 주세요.';

  @override
  String get settingsAppLockTemporarilyUnavailable =>
      '기기 인증을 일시적으로 사용할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get settingsAppLockUnavailableDevice => '이 기기에서는 기기 인증을 사용할 수 없습니다.';

  @override
  String get settingsAppLockSaveFailed => '앱 잠금 설정을 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get settingsAppLockSettingsFailed => '기기 보안 설정을 열 수 없습니다.';

  @override
  String get settingsOpenDeviceSettings => '기기 설정 열기';

  @override
  String get settingsAppearance => '화면';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsThemeSystem => '시스템';

  @override
  String get settingsThemeLight => '라이트';

  @override
  String get settingsThemeDark => '다크';

  @override
  String get settingsThemeSaveFailed => '테마를 저장할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get settingsReminders => '알림';

  @override
  String get settingsRemindersToggle => '매일 알림';

  @override
  String get settingsRemindersDescription => '아침과 저녁에 일기 쓰기 알림을 받으세요';

  @override
  String get settingsRemindersPermissionDenied =>
      '알림을 받으려면 알림 권한이 필요합니다. 기기 설정에서 활성화해 주세요.';

  @override
  String get reminderMorningTitle => 'wrait';

  @override
  String get reminderMorningBody => '오늘 하루를 되돌아보며 시작하세요';

  @override
  String get reminderEveningTitle => 'wrait';

  @override
  String get reminderEveningBody => '오늘 녹음이 아직 남아 있어요';

  @override
  String get settingsTranscriptionLanguage => '음성 인식 언어';

  @override
  String get settingsTranscriptionLanguageDescription =>
      '말하는 언어를 선택하면 음성 인식 정확도가 높아집니다. 언어를 선택하지 않으면 자동으로 감지합니다.';

  @override
  String get settingsAutomaticDetection => '자동 감지';

  @override
  String get settingsLoading => '불러오는 중…';

  @override
  String get settingsTranscriptionLanguageLoadFailed => '음성 인식 언어를 불러오지 못했습니다.';

  @override
  String get settingsTranscriptionLanguageSaveFailed =>
      '언어를 저장하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get settingsTryAgain => '다시 시도';

  @override
  String get settingsActivityMessage =>
      '설정을 변경하려면 진행 중인 녹음 또는 음성 인식을 먼저 마쳐 주세요.';

  @override
  String get entryListBack => '뒤로';

  @override
  String get entryListBackSemanticsLabel => '메인 화면으로 돌아가기';

  @override
  String get entryListSearchLabel => '기록 검색';

  @override
  String get entryListClearSearch => '검색어 지우기';

  @override
  String get entryListImportCsv => 'CSV 가져오기';

  @override
  String get entryListExportCsv => 'CSV 내보내기';

  @override
  String get entryListImporting => 'CSV 가져오는 중';

  @override
  String get entryListExporting => 'CSV 내보내는 중';

  @override
  String get entryListImportingSemanticsLabel => '기록을 가져오는 중';

  @override
  String get entryListExportingSemanticsLabel => '기록을 내보내는 중';

  @override
  String get entryListImportSemanticsLabel => '기록 가져오기';

  @override
  String get entryListExportSemanticsLabel => '기록 내보내기';

  @override
  String get entryListEmpty => '아직 기록이 없어요';

  @override
  String get entryListNoResults => '일치하는 기록이 없습니다';

  @override
  String entryListExportSuccess(String fileName, String pathLabel) {
    return '$fileName 파일을 $pathLabel에 내보냈습니다.';
  }

  @override
  String get entryListExportFailed => '기록을 내보내지 못했습니다.';

  @override
  String entryListImportSuccess(int count, String fileName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '기록 $count개',
    );
    return '$fileName에서 $_temp0를 가져왔습니다.';
  }

  @override
  String get entryListImportFailed => '기록을 가져오지 못했습니다.';

  @override
  String get entryListImportInvalidFormat =>
      '선택한 CSV는 올바른 Wrait 내보내기 파일이 아닙니다.';

  @override
  String get entryListImportUnreadableFile => '선택한 CSV 파일을 읽을 수 없습니다.';

  @override
  String get entryListImportFileTooLarge => '선택한 CSV 파일이 너무 커서 가져올 수 없습니다.';

  @override
  String get entryListImportStorageFailure => '가져온 기록을 저장하지 못했습니다.';

  @override
  String get entryListAudioDraftPreview => '대기 중 · 다시 시도할게요';

  @override
  String get entryListAudioDraftStateDescription =>
      '오디오 임시 저장본, 아직 텍스트로 변환되지 않음';

  @override
  String get entryListDeleteActionLabel => '기록 삭제';

  @override
  String entryListRowSemanticsLabel(String timestamp, String languageLabel) {
    return '기록 $timestamp. $languageLabel.';
  }

  @override
  String get entryListRowSwipeHint => '오른쪽으로 쓸어 삭제합니다.';

  @override
  String get entryListRowOpenHint => '두 번 탭하면 엽니다. 오른쪽으로 쓸어 삭제합니다.';

  @override
  String get entryListRowDraftBadge => '임시';

  @override
  String get entryListRowDraftValue => '임시 저장';

  @override
  String entryListRowAudioDraftValue(String description) {
    return '임시 저장, $description';
  }

  @override
  String get entryDetailSaving => '변경 사항을 저장하는 중...';

  @override
  String get entryDetailSaveFailed => '변경 사항을 저장하지 못했습니다.';

  @override
  String get entryDetailLoadFailed => '이 기록을 불러오지 못했습니다.';

  @override
  String get entryDetailEditSemanticsLabel => '기록 텍스트 편집';

  @override
  String get entryDetailEditHint => '기록을 편집하세요';

  @override
  String get entryDetailTapToEditHint => '눌러서 기록 편집';

  @override
  String get entryDetailBackSemanticsLabel => '기록 목록으로 돌아가기';

  @override
  String get entryDetailBack => '뒤로';

  @override
  String get entryDetailFinishEditingSemanticsLabel => '편집 완료';

  @override
  String get entryDetailEditEntrySemanticsLabel => '기록 편집';

  @override
  String get entryDetailDone => '완료';

  @override
  String get entryDetailEdit => '편집';

  @override
  String get entryDetailShareSemanticsLabel => '기록 공유';

  @override
  String get entryDetailShare => '공유';

  @override
  String get entryDetailDeleteSemanticsLabel => '기록 삭제';

  @override
  String get entryDetailDelete => '삭제';

  @override
  String get entryDetailShareFailed => '이 기록을 공유하지 못했습니다.';

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count단어',
    );
    return '$_temp0';
  }

  @override
  String get deleteDialogTitle => '기록을 삭제할까요?';

  @override
  String get deleteDialogBody => '이 기록은 영구적으로 삭제됩니다.';

  @override
  String get deleteCancel => '취소';

  @override
  String get deleteConfirm => '삭제';

  @override
  String get deleteCancelSemanticsLabel => '삭제 취소';

  @override
  String get deleteCancelSemanticsHint => '이 기록을 목록에 그대로 둡니다.';

  @override
  String get deleteConfirmSemanticsLabel => '기록 영구 삭제';

  @override
  String get deleteConfirmSemanticsHint => '이 기록을 목록에서 삭제합니다.';

  @override
  String get appLockTitle => 'wrait이 잠겨 있어요';

  @override
  String get appLockSemanticsLabel => 'Wrait이 잠겨 있습니다.';

  @override
  String get appLockUnlock => '잠금 해제';

  @override
  String get appLockOpenSettings => '설정 열기';

  @override
  String get appLockContinueWithout => '잠금 없이 계속';

  @override
  String get appLockStillLocked => '아직 잠겨 있어요';

  @override
  String get appLockSetUpSecurity => 'Wrait을 보호하려면 기기 보안을 설정해 주세요';

  @override
  String get appLockUnavailableTryAgain => '잠금 해제 불가 · 다시 시도해 주세요';

  @override
  String get appLockUnlockToContinue => '계속하려면 Wrait의 잠금을 해제해 주세요.';

  @override
  String get appLockSettingsWarning => '기기 보안을 설정하기 전까지는 내 일기가 그대로 보입니다.';

  @override
  String get appLockSemanticsHintUnlock => '두 번 탭하여 인증하고 계속합니다.';

  @override
  String get appLockSemanticsHintSettings =>
      '두 번 탭하여 다시 시도하거나, 설정을 열어 기기 보안을 구성하세요.';

  @override
  String get appLockSemanticsHintAuthInProgress => '인증이 진행 중입니다.';

  @override
  String get appLockPreferenceLoadFailed => 'Wrait이 개인정보 보호 설정을 불러오지 못했습니다.';

  @override
  String get appLockPreferenceLoading => '개인정보 보호 설정을 불러오는 중';

  @override
  String get appLockPreferenceRetry => '다시 시도';

  @override
  String get feedbackTitle => '의견 보내기';

  @override
  String get feedbackPrompt => '어떤 의견을 전하고 싶으신가요?';

  @override
  String get feedbackContactLabel => '답변받을 연락처 (선택)';

  @override
  String get feedbackContactHint => '연락 가능한 정보';

  @override
  String get feedbackMessageLabel => '의견';

  @override
  String get feedbackMessageHint => '전하고 싶은 내용을 적어 주세요';

  @override
  String get feedbackPrivacyCopy => '직접 입력하지 않는 한 개인적인 일기 내용은 포함하지 마세요.';

  @override
  String get feedbackCancel => '취소';

  @override
  String get feedbackSubmit => '보내기';

  @override
  String get feedbackDismissLabel => '의견 닫기';

  @override
  String get feedbackCategoryBug => '버그';

  @override
  String get feedbackCategoryIdea => '아이디어';

  @override
  String get feedbackCategoryConfusing => '헷갈려요';

  @override
  String get feedbackCategoryPraise => '칭찬';

  @override
  String get tagsTitle => '태그';

  @override
  String get tagsManage => '태그 관리';

  @override
  String get tagsAdd => '태그 추가';

  @override
  String get tagsAddHint => '태그 이름';

  @override
  String get tagsEmpty => '태그 없음';

  @override
  String tagsLimitReached(int max) {
    return '태그 한도에 도달했습니다 ($max)';
  }

  @override
  String get tagsDeleteConfirmTitle => '태그를 삭제할까요?';

  @override
  String get tagsDeleteConfirmBody => '이 태그가 모든 항목에서 제거됩니다.';

  @override
  String get tagsDeleteConfirm => '삭제';

  @override
  String get tagsDeleteCancel => '취소';

  @override
  String tagsNameTooLong(int max) {
    return '태그 이름은 $max자 이내여야 합니다';
  }

  @override
  String get tagsNameDuplicate => '이 태그는 이미 존재합니다';

  @override
  String get tagsCreateFailed => '태그를 만들 수 없습니다';

  @override
  String get tagsDeleteFailed => '태그를 삭제할 수 없습니다';

  @override
  String get tagsFilterAll => '전체';

  @override
  String get tagsFilterClear => '필터 지우기';

  @override
  String get tagsNoEntriesWithTag => '이 태그가 있는 항목이 없습니다';

  @override
  String get tagsAssign => '태그';

  @override
  String get tagsAssignDone => '완료';

  @override
  String tagsAssignCreate(String name) {
    return '\"$name\" 만들기';
  }

  @override
  String tagsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 항목',
    );
    return '$_temp0';
  }

  @override
  String get tagsSearchIncluded => '검색에 태그 이름이 포함됩니다';
}
