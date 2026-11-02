import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../domain/repository/app_lock_preferences_repository.dart';
import '../../domain/repository/preferences_repository.dart';
import '../../domain/repository/reminders_preferences_repository.dart';
import '../../domain/repository/theme_preferences_repository.dart';
import '../../domain/repository/transcription_language_preferences_repository.dart';
import 'platform_device_id_provider.dart';
import 'preferences_repository_impl.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'SharedPreferences must be provided at app startup.',
  ),
);

final platformDeviceIdProvider = Provider<PlatformDeviceIdProvider>(
  (ref) => const MethodChannelPlatformDeviceIdProvider(),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepositoryImpl(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    deviceIdProvider: ref.watch(platformDeviceIdProvider),
  ),
);

final debugDeviceModeProvider = FutureProvider<bool>((ref) async {
  final debugDeviceId = ref.watch(appConfigProvider).debugDeviceId;
  if (debugDeviceId.isEmpty) return false;
  final deviceId = await ref.watch(preferencesRepositoryProvider).getDeviceId();
  return deviceId == debugDeviceId;
});

final isDebugDeviceProvider = Provider<bool>((ref) {
  return ref.watch(debugDeviceModeProvider).value ?? false;
});

final transcriptionLanguagePreferencesRepositoryProvider =
    Provider<TranscriptionLanguagePreferencesRepository>((ref) {
      final repository = ref.watch(preferencesRepositoryProvider);
      return switch (repository) {
        TranscriptionLanguagePreferencesRepository languageRepository =>
          languageRepository,
        _ => const _AutomaticTranscriptionLanguagePreferencesRepository(),
      };
    });

final themePreferencesRepositoryProvider = Provider<ThemePreferencesRepository>(
  (ref) {
    final repository = ref.watch(preferencesRepositoryProvider);
    return switch (repository) {
      ThemePreferencesRepository themeRepository => themeRepository,
      _ => const _SystemThemePreferencesRepository(),
    };
  },
);

final appLockPreferencesRepositoryProvider =
    Provider<AppLockPreferencesRepository>((ref) {
      final repository = ref.watch(preferencesRepositoryProvider);
      return switch (repository) {
        AppLockPreferencesRepository appLockRepository => appLockRepository,
        _ => const _DisabledAppLockPreferencesRepository(),
      };
    });

final remindersPreferencesRepositoryProvider =
    Provider<RemindersPreferencesRepository>((ref) {
      final repository = ref.watch(preferencesRepositoryProvider);
      return switch (repository) {
        RemindersPreferencesRepository remindersRepository =>
          remindersRepository,
        _ => const _DisabledRemindersPreferencesRepository(),
      };
    });

class _DisabledRemindersPreferencesRepository
    implements RemindersPreferencesRepository {
  const _DisabledRemindersPreferencesRepository();

  @override
  Future<bool> getRemindersEnabled() async => false;

  @override
  Future<void> setRemindersEnabled(bool value) async {
    throw UnsupportedError('Reminders preferences are not writable.');
  }
}

class _DisabledAppLockPreferencesRepository
    implements AppLockPreferencesRepository {
  const _DisabledAppLockPreferencesRepository();

  @override
  Future<bool> getAppLockEnabled() async => false;

  @override
  Future<void> setAppLockEnabled(bool value) async {
    throw UnsupportedError('App-lock preferences are not writable.');
  }
}

class _SystemThemePreferencesRepository implements ThemePreferencesRepository {
  const _SystemThemePreferencesRepository();

  @override
  Future<String?> getThemeMode() async => null;

  @override
  Future<void> setThemeMode(String value) async {
    throw UnsupportedError('Theme preferences are not writable.');
  }
}

class _AutomaticTranscriptionLanguagePreferencesRepository
    implements TranscriptionLanguagePreferencesRepository {
  const _AutomaticTranscriptionLanguagePreferencesRepository();

  @override
  Future<String?> getTranscriptionLanguage() async => null;

  @override
  Future<void> setTranscriptionLanguage(String? language) async {
    throw UnsupportedError(
      'Transcription-language preferences are not writable.',
    );
  }
}
