import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../domain/repository/preferences_repository.dart';
import '../../domain/model/supported_language.dart';
import 'auth_interceptor.dart';
import 'backend_results.dart';
import 'device_token_store.dart';
import 'generated/backend_api_generated.dart';
import 'record_quota_state.dart';

typedef DelayFunction = Future<void> Function(Duration duration);

const tagTextMaxLength = 10000;

class WraitBackendClient {
  WraitBackendClient({
    required this.generatedClient,
    required this.registrarClient,
    required this.preferencesRepository,
    required this.deviceTokenStore,
    DelayFunction? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  static const maxRegisterAttempts = 3;
  static const baseRegisterRetryDelay = Duration(seconds: 1);

  /// Used for quota-protected calls; its Dio has the [AuthInterceptor] that
  /// attaches the token and recovers from 403s.
  final GeneratedBackendApiClient generatedClient;

  /// Used only for [register]; its Dio has no interceptor, so re-registration
  /// invoked from inside the interceptor can't deadlock.
  final GeneratedBackendApiClient registrarClient;

  final PreferencesRepository preferencesRepository;
  final DeviceTokenStore deviceTokenStore;
  final DelayFunction _delay;

  Future<RegistrationResult> register() async {
    // Independent reads — fetch concurrently off the launch critical path. The
    // backend picks verify-and-keep for a valid token and issue-new otherwise,
    // so a single call is always enough.
    final (deviceId, storedToken) =
        await (preferencesRepository.getDeviceId(), deviceTokenStore.read()).wait;

    for (var attempt = 0; attempt < maxRegisterAttempts; attempt += 1) {
      try {
        final response = await registrarClient.registerDevice(
          xDeviceId: deviceId,
          xDeviceToken: storedToken,
        );
        if (response is GeneratedApiSuccess<RegisterResponse>) {
          final issuedToken = response.data.token;
          if (issuedToken != null && issuedToken.isNotEmpty) {
            try {
              await deviceTokenStore.write(issuedToken);
            } catch (_) {
              // Intentionally emit no diagnostics here: the files that handle
              // the device token stay free of any logging sink (enforced by
              // device_token_log_audit_test) so the token can never leak.
              // Trade-off: a persistent secure-storage write failure means a
              // fresh token is issued on each call; the backend's per-IP Mode A
              // rate limit is the backstop against that becoming a loop.
            }
          }
          return RegistrationSuccess(
            quota: response.data.quota?.toValidatedStateOrNull(),
          );
        }

        final failure = response as GeneratedApiFailure<RegisterResponse>;
        if (failure.statusCode == 401) {
          return const RegistrationFailure(
            RegistrationFailureReason.proxyAuthFailed,
          );
        }

        if (failure.statusCode == 429) {
          return const RegistrationFailure(
            RegistrationFailureReason.rateLimited,
          );
        }

        if (failure.statusCode >= 500) {
          if (attempt == maxRegisterAttempts - 1) {
            return const RegistrationFailure(
              RegistrationFailureReason.transient,
            );
          }
          await _delay(_retryDelay(attempt));
          continue;
        }

        return const RegistrationFailure(RegistrationFailureReason.apiError);
      } on DioException catch (error) {
        if (_isTimeout(error) || _isNoInternet(error)) {
          if (attempt == maxRegisterAttempts - 1) {
            return const RegistrationFailure(
              RegistrationFailureReason.transient,
            );
          }
          await _delay(_retryDelay(attempt));
          continue;
        }

        return const RegistrationFailure(RegistrationFailureReason.apiError);
      } on FormatException {
        return const RegistrationFailure(RegistrationFailureReason.apiError);
      }
    }

    return const RegistrationFailure(RegistrationFailureReason.transient);
  }

  Future<TranscriptionResult> transcribeAudio(
    File audioFile, {
    String? language,
  }) async {
    if (language != null && !supportedLanguageCodes.contains(language)) {
      return const TranscriptionFailure(reason: BackendFailureReason.apiError);
    }
    try {
      final audioBytes = await audioFile.readAsBytes();
      final audioFilename = path.basename(audioFile.path);
      final response = await generatedClient.transcribeAudio(
        audioBytes: audioBytes,
        audioFilename: audioFilename,
        language: language,
      );

      if (response is GeneratedApiSuccess<TranscribeResponse>) {
        final transcript = response.data.transcript.trim();
        final detectedLanguage = response.data.detectedLanguage.trim();
        return TranscriptionSuccess(
          transcript: transcript,
          detectedLanguage: detectedLanguage.isEmpty ? null : detectedLanguage,
          quota: response.data.quota?.toValidatedStateOrNull(),
        );
      }

      final failure = response as GeneratedApiFailure<TranscribeResponse>;
      if (failure.statusCode == 422) {
        return const TranscriptionFailure(
          reason: BackendFailureReason.speechNotRecognized,
        );
      }
      return TranscriptionFailure(
        reason: _mapHttpFailureReason(failure.statusCode),
        quota: _quotaFromFailureData(failure.data),
      );
    } on DioException catch (error) {
      return TranscriptionFailure(reason: _mapDioFailureReason(error));
    } on FormatException {
      return const TranscriptionFailure(reason: BackendFailureReason.apiError);
    }
  }

  Future<CleanupResult> cleanupTranscript({
    required String transcript,
    required String language,
  }) async {
    try {
      final response = await generatedClient.cleanupTranscript(
        cleanupRequest: CleanupRequest(
          transcript: transcript,
          language: language,
        ),
      );

      if (response is GeneratedApiSuccess<CleanupResponse>) {
        final cleanedText = response.data.cleanedText.trim();
        if (cleanedText.isEmpty) {
          return CleanupFailure(
            reason: BackendFailureReason.apiError,
            quota: response.data.quota?.toValidatedStateOrNull(),
          );
        }

        return CleanupSuccess(
          cleanedText: cleanedText,
          quota: response.data.quota?.toValidatedStateOrNull(),
        );
      }

      final failure = response as GeneratedApiFailure<CleanupResponse>;
      return CleanupFailure(
        reason: _mapHttpFailureReason(failure.statusCode),
        quota: _quotaFromFailureData(failure.data),
      );
    } on DioException catch (error) {
      return CleanupFailure(reason: _mapDioFailureReason(error));
    } on FormatException {
      return const CleanupFailure(reason: BackendFailureReason.apiError);
    }
  }

  Future<TagTextResult> tagText({
    required String text,
    required List<String> tags,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TagTextFailure(reason: BackendFailureReason.apiError);
    }
    final boundedText = trimmed.length > tagTextMaxLength
        ? trimmed.substring(0, tagTextMaxLength)
        : trimmed;

    try {
      final response = await generatedClient.tagText(
        tagRequest: TagRequest(text: boundedText, tags: tags),
      );

      if (response is GeneratedApiSuccess<TagResponse>) {
        return TagTextSuccess(
          tags: response.data.tags
              .map(
                (item) => TagProbabilityResult(
                  tag: item.tag,
                  probability: item.probability,
                ),
              )
              .toList(growable: false),
        );
      }

      final failure = response as GeneratedApiFailure<TagResponse>;
      return TagTextFailure(reason: _mapHttpFailureReason(failure.statusCode));
    } on DioException catch (error) {
      return TagTextFailure(reason: _mapDioFailureReason(error));
    } on FormatException {
      return const TagTextFailure(reason: BackendFailureReason.apiError);
    }
  }

  Duration _retryDelay(int attempt) {
    return baseRegisterRetryDelay * (1 << attempt);
  }

  RecordQuotaState? _quotaFromFailureData(dynamic data) {
    if (data is! Map) {
      return null;
    }

    try {
      final parsed = DailyRecordLimitExceededResponse.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
      return parsed.quota.toValidatedStateOrNull();
    } on FormatException {
      return null;
    }
  }

  BackendFailureReason _mapHttpFailureReason(int statusCode) {
    if (statusCode == 413) {
      return BackendFailureReason.requestTooLarge;
    }
    if (statusCode == 429) {
      return BackendFailureReason.quotaExceeded;
    }
    if (statusCode == 401) {
      return BackendFailureReason.proxyAuthFailed;
    }
    if (statusCode == 403) {
      return BackendFailureReason.credentialRejected;
    }
    if (statusCode >= 500) {
      return BackendFailureReason.backendUnavailable;
    }
    return BackendFailureReason.apiError;
  }

  BackendFailureReason _mapDioFailureReason(DioException error) {
    // The AuthInterceptor rejects unrecoverable auth failures with this sentinel
    // so the precise reason survives to here.
    if (error.error is AuthFailure) {
      return (error.error as AuthFailure).reason;
    }
    if (_isTimeout(error)) {
      return BackendFailureReason.timeout;
    }
    if (_isNoInternet(error)) {
      return BackendFailureReason.noInternet;
    }

    return BackendFailureReason.apiError;
  }

  bool _isTimeout(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  bool _isNoInternet(DioException error) {
    if (error.type == DioExceptionType.connectionError) {
      return true;
    }

    return error.type == DioExceptionType.unknown &&
        error.error is SocketException;
  }
}
