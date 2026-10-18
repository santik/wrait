import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../domain/repository/preferences_repository.dart';
import '../../domain/model/supported_language.dart';
import 'backend_results.dart';
import 'generated/backend_api_generated.dart';
import 'record_quota_state.dart';

typedef DelayFunction = Future<void> Function(Duration duration);

const tagTextMaxLength = 10000;

class WraitBackendClient {
  WraitBackendClient({
    required this.generatedClient,
    required this.preferencesRepository,
    DelayFunction? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  static const maxRegisterAttempts = 3;
  static const baseRegisterRetryDelay = Duration(seconds: 1);

  final GeneratedBackendApiClient generatedClient;
  final PreferencesRepository preferencesRepository;
  final DelayFunction _delay;

  Future<RegistrationResult> register() async {
    final deviceId = await preferencesRepository.getDeviceId();

    for (var attempt = 0; attempt < maxRegisterAttempts; attempt += 1) {
      try {
        final response = await generatedClient.registerDevice(
          xDeviceId: deviceId,
        );
        if (response is GeneratedApiSuccess<RegisterResponse>) {
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
      final deviceId = await preferencesRepository.getDeviceId();
      final response = await generatedClient.transcribeAudio(
        xDeviceId: deviceId,
        audioBytes: await audioFile.readAsBytes(),
        audioFilename: path.basename(audioFile.path),
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
      final deviceId = await preferencesRepository.getDeviceId();
      final response = await generatedClient.cleanupTranscript(
        xDeviceId: deviceId,
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
      final deviceId = await preferencesRepository.getDeviceId();
      final response = await generatedClient.tagText(
        xDeviceId: deviceId,
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
    if (statusCode == 502 || statusCode == 504) {
      return BackendFailureReason.backendUnavailable;
    }
    if (statusCode >= 500) {
      return BackendFailureReason.backendUnavailable;
    }
    return BackendFailureReason.apiError;
  }

  BackendFailureReason _mapDioFailureReason(DioException error) {
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
