import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/l10n/app_localizations.dart';
import 'package:wrait/presentation/main/main_screen_status.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() {
    l10n = testL10n();
  });

  test('returns the first-time idle presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(),
      hasEverRecorded: false,
      l10n: l10n,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'tap button to write');
    expect(presentation.action, MainScreenStatusAction.startRecording);
  });

  test('returns the returning-user idle presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'wrait');
    expect(presentation.action, isNull);
  });

  test('returns the listening presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(presentation.buttonLabel, 'stop');
    expect(presentation.statusText, 'listening...');
  });

  test('returns the saved presentation with detail navigation action', () {
    final presentation = resolveMainScreenStatus(
      controllerState: RecordingControllerState(
        recordingState: RecordingSaved(entryId: 14, detectedLanguage: 'en-US'),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'saved, tap to read');
    expect(presentation.action, MainScreenStatusAction.openSavedEntry);
    expect(presentation.savedEntryId, 14);
  });

  test('maps the rate limit error to the retriable status (no draft)', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.rateLimited),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(presentation.statusText, 'busy right now · try again soon');
  });

  test('maps the rate limit error to the draft-preserved status', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(
          RecordingError.rateLimited,
          preservedDraft: true,
        ),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(
      presentation.statusText,
      'busy right now · saved as draft, try again soon',
    );
  });

  test('returns approved draft-preserved copy by error category', () {
    final cases = <RecordingState, String>{
      const RecordingErrorState(
        RecordingError.noInternet,
        preservedDraft: true,
      ): 'no connection · saved as draft',
      const RecordingErrorState(
        RecordingError.backendUnavailable,
        preservedDraft: true,
      ): 'service unavailable · saved as draft',
      const RecordingErrorState(
        RecordingError.proxyAuthFailed,
        preservedDraft: true,
      ): 'server config error · saved as draft',
      const RecordingErrorState(
        RecordingError.speechNotRecognized,
        preservedDraft: true,
      ): 'not recognized · saved as draft',
      const RecordingErrorState(RecordingError.apiFailed, preservedDraft: true):
          'saved as draft · will retry',
    };

    for (final entry in cases.entries) {
      final presentation = resolveMainScreenStatus(
        controllerState: RecordingControllerState(recordingState: entry.key),
        hasEverRecorded: true,
        l10n: l10n,
      );

      expect(presentation.statusText, entry.value);
    }
  });

  test('returns approved error copy for specific non-draft errors', () {
    final cases = <RecordingState, String>{
      const RecordingErrorState(RecordingError.tooShort):
          'too short · keep talking',
      const RecordingErrorState(RecordingError.noMatch):
          'nothing caught · too quiet?',
      const RecordingErrorState(RecordingError.microphoneDenied):
          'mic needed · tap again',
      const RecordingErrorState(RecordingError.microphoneBlocked):
          'mic blocked · tap settings',
      const RecordingErrorState(RecordingError.noInternet): 'no connection',
      const RecordingErrorState(RecordingError.backendUnavailable):
          'service unavailable',
      const RecordingErrorState(RecordingError.proxyAuthFailed):
          'server config error',
      const RecordingErrorState(RecordingError.speechNotRecognized):
          'not recognized',
      const RecordingErrorState(RecordingError.apiFailed):
          'something went wrong',
      const RecordingDeleted(2): 'deleted',
      const RecordingUploading(): 'processing...',
      const RecordingProcessing(): 'cleaning up...',
    };

    for (final entry in cases.entries) {
      final presentation = resolveMainScreenStatus(
        controllerState: RecordingControllerState(recordingState: entry.key),
        hasEverRecorded: true,
        l10n: l10n,
      );
      expect(presentation.statusText, entry.value);
    }
  });

  test('returns microphone settings action for blocked microphone status', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.microphoneBlocked),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(presentation.action, MainScreenStatusAction.openMicrophoneSettings);
  });

  test('returns permission-specific accessibility copy for denied and blocked states', () {
    final denied = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.microphoneDenied),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );
    final blocked = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(RecordingError.microphoneBlocked),
      ),
      hasEverRecorded: true,
      l10n: l10n,
    );

    expect(
      denied.semanticsLabel,
      'Microphone access is required to start recording.',
    );
    expect(
      denied.semanticsHint,
      'Double tap to request microphone access again.',
    );
    expect(blocked.semanticsLabel, 'Microphone access is blocked for Wrait.');
    expect(blocked.semanticsHint, 'Double tap to open app settings.');
  });
}
