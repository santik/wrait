import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app.dart';
import '../../domain/usecase/auto_tag_use_case.dart';
import '../../domain/usecase/cleanup_transcript_use_case.dart';
import '../../domain/usecase/register_device_on_launch_use_case.dart';
import '../entries/database_key_store.dart';
import '../entries/entry_providers.dart';
import '../entries/tag_providers.dart';
import '../preferences/preferences_providers.dart';
import 'auth_interceptor.dart';
import 'backend_client.dart';
import 'backend_results.dart';
import 'device_token_store.dart';
import 'generated/backend_api_generated.dart';
import 'record_quota_state.dart';

const backendConnectTimeout = Duration(seconds: 15);
const backendSendTimeout = Duration(seconds: 60);
const backendReceiveTimeout = Duration(seconds: 60);

Dio _backendDio(Ref ref) {
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
}

/// Interceptor-free Dio used only for device registration, so re-registration
/// triggered from inside [AuthInterceptor] can't deadlock on the main Dio.
final registrarDioProvider = Provider<Dio>((ref) => _backendDio(ref));

final registrarGeneratedClientProvider = Provider<GeneratedBackendApiClient>((
  ref,
) {
  return DioGeneratedBackendApiClient(ref.watch(registrarDioProvider));
});

/// Registrar-only client the [AuthInterceptor] re-registers through. It depends
/// solely on the registrar Dio (never [backendDioProvider]), which is what
/// breaks the provider cycle backendDio -> wraitBackendClient ->
/// generatedBackendApiClient -> backendDio that Riverpod would otherwise throw
/// on the moment the interceptor invoked re-registration. See [AuthInterceptor]
/// for the full rationale behind the separate registrar Dio.
final Provider<WraitBackendClient> deviceRegistrarProvider =
    Provider<WraitBackendClient>((ref) {
  final registrar = ref.watch(registrarGeneratedClientProvider);
  return WraitBackendClient(
    // register() only touches registrarClient/preferences/tokenStore; the
    // generated-client slot is required but unused on this instance, so the
    // registrar client fills it to keep this provider off backendDio.
    generatedClient: registrar,
    registrarClient: registrar,
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
    deviceTokenStore: ref.watch(deviceTokenStoreProvider),
  );
});

/// Main Dio for quota-protected calls. [AuthInterceptor] attaches the device
/// token and, on a 403, re-registers (on the registrar Dio) and retries once.
final Provider<Dio> backendDioProvider = Provider<Dio>((ref) {
  final dio = _backendDio(ref);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      deviceTokenStore: ref.watch(deviceTokenStoreProvider),
      reRegister: () => ref.read(deviceRegistrarProvider).register(),
    ),
  );
  return dio;
});

final Provider<GeneratedBackendApiClient> generatedBackendApiClientProvider =
    Provider<GeneratedBackendApiClient>((ref) {
      return DioGeneratedBackendApiClient(ref.watch(backendDioProvider));
    });

final deviceTokenStoreProvider = Provider<DeviceTokenStore>((ref) {
  return DeviceTokenStore(
    FlutterSecureKeyValueStore(
      // resetOnError mirrors the existing database key store
      // (entry_providers.dart): on a rare Android keystore error the store
      // resets, which only drops the device token and triggers a harmless
      // re-registration on the next call — never user data loss.
      const FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: true)),
    ),
  );
});

final Provider<WraitBackendClient> wraitBackendClientProvider =
    Provider<WraitBackendClient>((ref) {
  return WraitBackendClient(
    deviceTokenStore: ref.watch(deviceTokenStoreProvider),
    generatedClient: ref.watch(generatedBackendApiClientProvider),
    registrarClient: ref.watch(registrarGeneratedClientProvider),
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

typedef TagTextCallback = Future<TagTextResult> Function({
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
