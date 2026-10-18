import 'record_quota_state.dart';

enum BackendFailureReason {
  timeout,
  noInternet,
  requestTooLarge,
  quotaExceeded,
  proxyAuthFailed,
  backendUnavailable,
  speechNotRecognized,
  apiError,
}

enum RegistrationFailureReason { transient, proxyAuthFailed, apiError }

sealed class RegistrationResult {
  const RegistrationResult();
}

final class RegistrationSuccess extends RegistrationResult {
  const RegistrationSuccess({this.quota});

  final RecordQuotaState? quota;
}

final class RegistrationFailure extends RegistrationResult {
  const RegistrationFailure(this.reason);

  final RegistrationFailureReason reason;
}

sealed class TranscriptionResult {
  const TranscriptionResult();
}

final class TranscriptionSuccess extends TranscriptionResult {
  const TranscriptionSuccess({
    required this.transcript,
    required this.detectedLanguage,
    this.quota,
  });

  final String transcript;
  final String? detectedLanguage;
  final RecordQuotaState? quota;
}

final class TranscriptionFailure extends TranscriptionResult {
  const TranscriptionFailure({required this.reason, this.quota});

  final BackendFailureReason reason;
  final RecordQuotaState? quota;
}

sealed class CleanupResult {
  const CleanupResult();
}

final class CleanupSuccess extends CleanupResult {
  const CleanupSuccess({required this.cleanedText, this.quota});

  final String cleanedText;
  final RecordQuotaState? quota;
}

final class CleanupFailure extends CleanupResult {
  const CleanupFailure({required this.reason, this.quota});

  final BackendFailureReason reason;
  final RecordQuotaState? quota;
}

sealed class TagTextResult {
  const TagTextResult();
}

final class TagTextSuccess extends TagTextResult {
  const TagTextSuccess({required this.tags});

  final List<TagProbabilityResult> tags;
}

final class TagTextFailure extends TagTextResult {
  const TagTextFailure({required this.reason});

  final BackendFailureReason reason;
}

class TagProbabilityResult {
  const TagProbabilityResult({required this.tag, required this.probability});

  final String tag;
  final double probability;
}
