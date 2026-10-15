import 'package:flutter/foundation.dart';

const settingsBackButtonKey = ValueKey<String>('settingsBackButton');
const transcriptionLanguageSectionKey = ValueKey<String>(
  'transcriptionLanguageSection',
);
const transcriptionLanguageDropdownKey = ValueKey<String>(
  'transcriptionLanguageDropdown',
);
const transcriptionLanguageFocusKey = ValueKey<String>(
  'transcriptionLanguageFocus',
);
const transcriptionLanguageAutomaticKey = ValueKey<String>(
  'transcriptionLanguageOption:auto',
);
const transcriptionLanguageSavingKey = ValueKey<String>(
  'transcriptionLanguageSaving',
);
const transcriptionLanguageErrorKey = ValueKey<String>(
  'transcriptionLanguageError',
);
const transcriptionLanguageRetryKey = ValueKey<String>(
  'transcriptionLanguageRetry',
);

ValueKey<String> transcriptionLanguageOptionKey(String code) =>
    ValueKey<String>('transcriptionLanguageOption:$code');
const themeSegmentedButtonKey = ValueKey<String>('themeSegmentedButton');
const themeSystemSegmentKey = ValueKey<String>('themeSegment:system');
const themeLightSegmentKey = ValueKey<String>('themeSegment:light');
const themeDarkSegmentKey = ValueKey<String>('themeSegment:dark');
const themeSaveFailedKey = ValueKey<String>('themeSaveFailed');

const appLockSwitchKey = ValueKey<String>('appLockSwitch');
const appLockPreferenceErrorKey = ValueKey<String>('appLockPreferenceError');
const appLockDeviceSettingsKey = ValueKey<String>('appLockDeviceSettings');

const remindersToggleKey = ValueKey<String>('remindersToggle');
const remindersPermissionDeniedKey = ValueKey<String>(
  'remindersPermissionDenied',
);
const remindersOpenSettingsKey = ValueKey<String>('remindersOpenSettings');
