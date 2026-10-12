import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';
import 'package:wrait/data/preferences/preferences_repository_impl.dart';

void main() {
  final hashedDeviceIdPattern = RegExp(r'^[0-9a-f]{64}$');

  late _FakePreferencesStore preferencesStore;
  late PreferencesRepositoryImpl repository;
  late _FakePlatformDeviceIdProvider deviceIdProvider;

  setUp(() {
    preferencesStore = _FakePreferencesStore();
    deviceIdProvider = _FakePlatformDeviceIdProvider('device-id-001');
    repository = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: deviceIdProvider,
    );
  });

  test('hasEverRecorded defaults to false when unset', () async {
    await expectLater(repository.getHasEverRecorded(), completion(isFalse));
  });

  test(
    'transcription language defaults to automatic and persists exact codes',
    () async {
      expect(await repository.getTranscriptionLanguage(), isNull);

      await repository.setTranscriptionLanguage('de-CH');
      expect(await repository.getTranscriptionLanguage(), 'de-CH');

      await repository.setTranscriptionLanguage(null);
      expect(await repository.getTranscriptionLanguage(), isNull);
    },
  );

  test('invalid stored transcription language resolves to automatic', () async {
    preferencesStore.stringValues[PreferencesRepositoryImpl
            .transcriptionLanguageKey] =
        'en-US';

    expect(await repository.getTranscriptionLanguage(), isNull);
  });

  test('rejects unsupported transcription language without writing', () async {
    await expectLater(
      repository.setTranscriptionLanguage('multi'),
      throwsArgumentError,
    );
    expect(
      preferencesStore.stringValues[PreferencesRepositoryImpl
          .transcriptionLanguageKey],
      isNull,
    );
  });

  test('theme mode defaults to null (system) when unset', () async {
    expect(await repository.getThemeMode(), isNull);
  });

  test('theme mode persists valid values and survives recreation', () async {
    await repository.setThemeMode('dark');
    expect(await repository.getThemeMode(), 'dark');

    await repository.setThemeMode('light');
    expect(await repository.getThemeMode(), 'light');

    await repository.setThemeMode('system');
    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider(null),
    );
    expect(await recreated.getThemeMode(), 'system');
  });

  test('invalid stored theme mode resolves to null', () async {
    preferencesStore.stringValues[PreferencesRepositoryImpl.themeModeKey] =
        'neon';
    expect(await repository.getThemeMode(), isNull);
  });

  test('rejects unsupported theme mode without writing', () async {
    await expectLater(
      repository.setThemeMode('neon'),
      throwsArgumentError,
    );
    expect(
      preferencesStore.stringValues[PreferencesRepositoryImpl.themeModeKey],
      isNull,
    );
  });

  test('failed theme mode write throws StateError', () async {
    preferencesStore.failStringWrites = true;
    await expectLater(
      repository.setThemeMode('dark'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Failed to persist themeMode',
        ),
      ),
    );
  });

  test('app lock defaults to false when unset', () async {
    await expectLater(repository.getAppLockEnabled(), completion(isFalse));
  });

  test('app lock persists explicit true and false values', () async {
    await repository.setAppLockEnabled(true);
    expect(await repository.getAppLockEnabled(), isTrue);

    await repository.setAppLockEnabled(false);
    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider(null),
    );
    expect(await recreated.getAppLockEnabled(), isFalse);
  });

  test('app lock rejects a stored value of the wrong type', () async {
    preferencesStore.stringValues[PreferencesRepositoryImpl.appLockEnabledKey] =
        'true';

    await expectLater(repository.getAppLockEnabled(), throwsStateError);
  });

  test(
    'failed app-lock write retains the confirmed value and reloads',
    () async {
      expect(await repository.getAppLockEnabled(), isFalse);
      preferencesStore.failBoolWrites = true;
      preferencesStore.mutateCacheBeforeFailedBoolWrite = true;

      await expectLater(repository.setAppLockEnabled(true), throwsStateError);

      expect(preferencesStore.reloadCount, 1);
      expect(await repository.getAppLockEnabled(), isFalse);
      final recreated = PreferencesRepositoryImpl(
        preferencesStore: preferencesStore,
        deviceIdProvider: _FakePlatformDeviceIdProvider(null),
      );
      expect(await recreated.getAppLockEnabled(), isFalse);
    },
  );

  test(
    'failed cache reload still retains the confirmed app-lock value',
    () async {
      expect(await repository.getAppLockEnabled(), isFalse);
      preferencesStore
        ..failBoolWrites = true
        ..mutateCacheBeforeFailedBoolWrite = true
        ..failReload = true;

      await expectLater(repository.setAppLockEnabled(true), throwsStateError);

      expect(await repository.getAppLockEnabled(), isFalse);
    },
  );

  test('hasEverRecorded persists true across repository re-creation', () async {
    await repository.setHasEverRecorded(true);

    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider('device-id-001'),
    );

    await expectLater(recreated.getHasEverRecorded(), completion(isTrue));
  });

  test('hasEverRecorded persists false after being reset from true', () async {
    await repository.setHasEverRecorded(true);
    await repository.setHasEverRecorded(false);

    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider('device-id-001'),
    );

    await expectLater(recreated.getHasEverRecorded(), completion(isFalse));
  });

  test(
    'setHasEverRecorded throws when persistence reports a failed write',
    () async {
      preferencesStore.failBoolWrites = true;

      await expectLater(
        repository.setHasEverRecorded(true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Failed to persist hasEverRecorded',
          ),
        ),
      );
    },
  );

  test(
    'getDeviceId returns an already stored value without querying the platform',
    () async {
      preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey] =
          'stored-device-id';

      final first = await repository.getDeviceId();
      final second = await repository.getDeviceId();

      expect(first, 'stored-device-id');
      expect(second, 'stored-device-id');
      expect(deviceIdProvider.callCount, 0);
    },
  );

  test('getDeviceId stores and reuses a hashed platform value when available first', () async {
    final first = await repository.getDeviceId();
    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider(null),
    );
    final second = await recreated.getDeviceId();

    expect(first, matches(hashedDeviceIdPattern));
    expect(first, isNot('device-id-001'));
    expect(second, first);
    expect(
      preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey],
      first,
    );
    expect(deviceIdProvider.callCount, 1);
  });

  test('getDeviceId generates, hashes, stores, and reuses a fallback when platform is unavailable', () async {
    final fallbackRepository = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider(null),
      random: _DeterministicRandom(),
    );
    final first = await fallbackRepository.getDeviceId();
    final recreated = PreferencesRepositoryImpl(
      preferencesStore: preferencesStore,
      deviceIdProvider: _FakePlatformDeviceIdProvider('platform-now-available'),
    );
    final second = await recreated.getDeviceId();

    expect(first, matches(hashedDeviceIdPattern));
    expect(first, isNot('00112233445566778899aabbccddeeff'));
    expect(second, first);
    expect(
      preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey],
      first,
    );
  });

  test('getDeviceId caches the first resolved value in memory', () async {
    final first = await repository.getDeviceId();
    deviceIdProvider.value = 'device-id-002';
    final second = await repository.getDeviceId();

    expect(first, matches(hashedDeviceIdPattern));
    expect(second, first);
    expect(deviceIdProvider.callCount, 1);
  });

  test(
    'getDeviceId hides whether the stored value came from platform or fallback',
    () async {
      final platformResolved = await repository.getDeviceId();

      final fallbackResolvedRepository = PreferencesRepositoryImpl(
        preferencesStore: _FakePreferencesStore(),
        deviceIdProvider: _FakePlatformDeviceIdProvider(null),
        random: _DeterministicRandom(),
      );
      final fallbackResolved = await fallbackResolvedRepository.getDeviceId();

      expect(platformResolved, isA<String>());
      expect(fallbackResolved, isA<String>());
      expect(platformResolved, isNotEmpty);
      expect(fallbackResolved, isNotEmpty);
      expect(platformResolved, matches(hashedDeviceIdPattern));
      expect(fallbackResolved, matches(hashedDeviceIdPattern));
    },
  );

  test('getDeviceId preserves a preexisting stored value unchanged even if it is not backend-compatible', () async {
    preferencesStore.stringValues[PreferencesRepositoryImpl.deviceIdKey] =
        'legacy-device-id';

    final resolved = await repository.getDeviceId();

    expect(resolved, 'legacy-device-id');
    expect(deviceIdProvider.callCount, 0);
  });
}

class _FakePlatformDeviceIdProvider implements PlatformDeviceIdProvider {
  _FakePlatformDeviceIdProvider(this._initialValue);

  final String? _initialValue;
  int callCount = 0;
  String? value;

  @override
  Future<String?> getPlatformDeviceId() async {
    callCount += 1;
    return value ?? _initialValue;
  }
}

class _FakePreferencesStore implements PreferencesStore {
  final Map<String, bool> boolValues = {};
  final Map<String, String> stringValues = {};
  final Map<String, bool> persistedBoolValues = {};
  bool failBoolWrites = false;
  bool failStringWrites = false;
  bool failRemoves = false;
  bool mutateCacheBeforeFailedBoolWrite = false;
  bool failReload = false;
  int reloadCount = 0;

  @override
  Object? get(String key) => boolValues[key] ?? stringValues[key];

  @override
  bool? getBool(String key) => boolValues[key];

  @override
  String? getString(String key) => stringValues[key];

  @override
  Future<bool> setBool(String key, bool value) async {
    if (failBoolWrites) {
      if (mutateCacheBeforeFailedBoolWrite) {
        boolValues[key] = value;
      }
      return false;
    }

    boolValues[key] = value;
    persistedBoolValues[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failStringWrites) {
      return false;
    }

    stringValues[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemoves) {
      return false;
    }
    boolValues.remove(key);
    stringValues.remove(key);
    return true;
  }

  @override
  Future<void> reload() async {
    reloadCount += 1;
    if (failReload) {
      throw StateError('reload failed');
    }
    boolValues
      ..clear()
      ..addAll(persistedBoolValues);
  }
}

class _DeterministicRandom extends _FakeRandom {
  @override
  int nextInt(int max) {
    const bytes = <int>[
      0x00,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x99,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
    ];
    final value = bytes[_index % bytes.length];
    _index += 1;
    return value % max;
  }
}

abstract class _FakeRandom implements Random {
  int _index = 0;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  int nextInt(int max);
}
