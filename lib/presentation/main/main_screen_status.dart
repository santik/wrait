import '../../l10n/app_localizations.dart';
import 'recording_state.dart';

enum MainScreenStatusAction {
  startRecording,
  openSavedEntry,
  openMicrophoneSettings,
}

class MainScreenStatusPresentation {
  const MainScreenStatusPresentation({
    required this.buttonLabel,
    required this.statusText,
    this.action,
    this.savedEntryId,
    this.semanticsLabel,
    this.semanticsHint,
  });

  final String buttonLabel;
  final String statusText;
  final MainScreenStatusAction? action;
  final int? savedEntryId;
  final String? semanticsLabel;
  final String? semanticsHint;

  bool get isStatusTappable => action != null;
}

MainScreenStatusPresentation resolveMainScreenStatus({
  required RecordingControllerState controllerState,
  required bool hasEverRecorded,
  required AppLocalizations l10n,
}) {
  final recordingState = controllerState.recordingState;
  final buttonLabel = switch (recordingState) {
    RecordingListening() => l10n.mainButtonStop,
    _ => l10n.mainButtonWrait,
  };

  return switch (recordingState) {
    RecordingIdle() when !hasEverRecorded => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusTapToWrite,
      action: MainScreenStatusAction.startRecording,
    ),
    RecordingIdle() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusWrait,
    ),
    RecordingListening() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusListening,
    ),
    RecordingUploading() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusProcessing,
    ),
    RecordingProcessing() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusCleaningUp,
    ),
    RecordingSaved(entryId: final entryId) => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusSavedTapToRead,
      action: MainScreenStatusAction.openSavedEntry,
      savedEntryId: entryId,
    ),
    RecordingDeleted() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: l10n.statusDeleted,
    ),
    RecordingErrorState(
      error: RecordingError.noInternet,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusNoConnectionDraft,
      ),
    RecordingErrorState(
      error: RecordingError.backendUnavailable,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusServiceUnavailableDraft,
      ),
    RecordingErrorState(
      error: RecordingError.proxyAuthFailed,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusServerConfigErrorDraft,
      ),
    RecordingErrorState(
      error: RecordingError.rateLimited,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusRateLimitedDraft,
      ),
    RecordingErrorState(
      error: RecordingError.speechNotRecognized,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusSpeechNotRecognizedDraft,
      ),
    RecordingErrorState(
      error: RecordingError.apiFailed,
      preservedDraft: true,
    ) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusApiFailedDraft,
      ),
    RecordingErrorState(error: RecordingError.tooShort) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusTooShort,
      ),
    RecordingErrorState(error: RecordingError.noMatch) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusNothingCaught,
      ),
    RecordingErrorState(error: RecordingError.microphoneDenied) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusMicNeeded,
        action: MainScreenStatusAction.startRecording,
        semanticsLabel: l10n.statusMicNeededSemanticsLabel,
        semanticsHint: l10n.statusMicNeededSemanticsHint,
      ),
    RecordingErrorState(error: RecordingError.microphoneBlocked) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusMicBlocked,
        action: MainScreenStatusAction.openMicrophoneSettings,
        semanticsLabel: l10n.statusMicBlockedSemanticsLabel,
        semanticsHint: l10n.statusMicBlockedSemanticsHint,
      ),
    RecordingErrorState(error: RecordingError.noInternet) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusNoConnection,
      ),
    RecordingErrorState(error: RecordingError.backendUnavailable) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusServiceUnavailable,
      ),
    RecordingErrorState(error: RecordingError.proxyAuthFailed) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusServerConfigError,
      ),
    RecordingErrorState(error: RecordingError.rateLimited) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusRateLimited,
      ),
    RecordingErrorState(error: RecordingError.speechNotRecognized) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusSpeechNotRecognized,
      ),
    RecordingErrorState(error: RecordingError.apiFailed) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: l10n.statusSomethingWentWrong,
      ),
  };
}
