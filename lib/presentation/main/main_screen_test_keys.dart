import 'package:flutter/foundation.dart';

// Stable selectors for automated tests that need to verify the main-screen
// launch surface without coupling to transient copy.
const mainActionButtonKey = ValueKey<String>('actionButton');
const mainActionButtonLabelKey = ValueKey<String>('actionButtonLabel');
const mainStatusLineSlotKey = ValueKey<String>('statusLineSlot');
const mainFeedbackButtonKey = ValueKey<String>('mainFeedbackButton');
const mainSettingsButtonKey = ValueKey<String>('mainSettingsButton');
const mainTranscriptionLanguageKey = ValueKey<String>(
  'mainTranscriptionLanguage',
);
const mainTranscriptionLanguageRetryKey = ValueKey<String>(
  'mainTranscriptionLanguageRetry',
);
