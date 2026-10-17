import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';

void main() {
  test('returns false when debugDeviceId is empty', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromValues()),
        preferencesRepositoryProvider.overrideWithValue(
          _FakePreferencesRepository('test-id'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(debugDeviceModeProvider.future), isFalse);
  });

  test('returns true when device ID matches debugDeviceId', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(debugDeviceId: 'test-id'),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          _FakePreferencesRepository('test-id'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(debugDeviceModeProvider.future), isTrue);
  });

  test('returns false when device ID differs from debugDeviceId', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(debugDeviceId: 'test-id'),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          _FakePreferencesRepository('other-id'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(debugDeviceModeProvider.future), isFalse);
  });
}

class _FakePreferencesRepository implements PreferencesRepository {
  _FakePreferencesRepository(this._deviceId);

  final String _deviceId;

  @override
  Future<String> getDeviceId() async => _deviceId;

  @override
  Future<bool> getHasEverRecorded() => throw UnimplementedError();

  @override
  Future<void> setHasEverRecorded(bool value) => throw UnimplementedError();
}
