import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../domain/usecase/auto_tag_use_case.dart';
import '../../domain/usecase/cleanup_transcript_use_case.dart';
import '../../domain/usecase/register_device_on_launch_use_case.dart';
import '../entries/entry_providers.dart';
import '../entries/tag_providers.dart';
import '../preferences/preferences_providers.dart';
import 'backend_client.dart';
import 'backend_results.dart';
import 'generated/backend_api_generated.dart';
import 'record_quota_state.dart';

const backendConnectTimeout = Duration(seconds: 15);
const backendSendTimeout = Duration(seconds: 60);
const backendReceiveTimeout = Duration(seconds: 60);

final backendDioProvider = Provider<Dio>((ref) {
  final appConfig = ref.watch(appConfigProvider);

  return Dio(
    BaseOptions(
      baseUrl: appConfig.backendUrl,
      headers: <String, dynamic>{'X-Proxy-Secret': appConfig.proxySecret},
      connectTimeout: backendConnectTimeout,
      sendTimeout: backendSendTimeout,
      receiveTimeout: backendReceiveTimeout,
    ),
  );
});

final generatedBackendApiClientProvider = Provider<GeneratedBackendApiClient>((
  ref,
) {
  return DioGeneratedBackendApiClient(ref.watch(backendDioProvider));
});

final wraitBackendClientProvider = Provider<WraitBackendClient>((ref) {
  return WraitBackendClient(
    generatedClient: ref.watch(generatedBackendApiClientProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
  );
});

final cleanupTranscriptCallbackProvider = Provider<CleanupTranscriptCallback>((
  ref,
) {
  return ({required String transcript, required String language}) {
    return ref
        .watch(wraitBackendClientProvider)
        .cleanupTranscript(transcript: transcript, language: language);
  };
});

class SessionRecordQuotaStateNotifier extends Notifier<RecordQuotaState?> {
  @override
  RecordQuotaState? build() => null;

  void setQuota(RecordQuotaState quota) {
    state = quota;
  }
}

final sessionRecordQuotaStateProvider =
    NotifierProvider<SessionRecordQuotaStateNotifier, RecordQuotaState?>(
      SessionRecordQuotaStateNotifier.new,
    );

@Deprecated('Use sessionRecordQuotaStateProvider instead.')
final registrationQuotaStateProvider = sessionRecordQuotaStateProvider;

final registrationWarningLoggerProvider = Provider<RegistrationWarningLogger>((
  ref,
) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'DeviceRegistration',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final cleanupWarningLoggerProvider = Provider<CleanupWarningLogger>((ref) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'CleanupTranscriptUseCase',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final registerDeviceOnLaunchUseCaseProvider =
    Provider<RegisterDeviceOnLaunchUseCase>((ref) {
      return RegisterDeviceOnLaunchUseCase(
        registerDevice: ref.watch(wraitBackendClientProvider).register,
        setRecordQuota: (quota) {
          ref.read(sessionRecordQuotaStateProvider.notifier).setQuota(quota);
        },
        logWarning: ref.watch(registrationWarningLoggerProvider),
      );
    });

final cleanupTranscriptUseCaseProvider = Provider<CleanupTranscriptUseCase>((
  ref,
) {
  return CleanupTranscriptUseCase(
    cleanupTranscript: ref.watch(cleanupTranscriptCallbackProvider),
    entryRepository: ref.watch(entryRepositoryProvider),
    setRecordQuota: (quota) {
      ref.read(sessionRecordQuotaStateProvider.notifier).setQuota(quota);
    },
    logWarning: ref.watch(cleanupWarningLoggerProvider),
  );
});

typedef TagTextCallback =
    Future<TagTextResult> Function({
      required String text,
      required List<String> tags,
    });

final tagTextCallbackProvider = Provider<TagTextCallback>((ref) {
  return ({required String text, required List<String> tags}) {
    return ref
        .watch(wraitBackendClientProvider)
        .tagText(text: text, tags: tags);
  };
});

final autoTagWarningLoggerProvider = Provider<AutoTagWarningLogger>((ref) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'AutoTagUseCase',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final autoTagUseCaseProvider = Provider<AutoTagUseCase>((ref) {
  return AutoTagUseCase(
    tagRepository: ref.watch(tagRepositoryProvider),
    logWarning: ref.watch(autoTagWarningLoggerProvider),
  );
});
