import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/display/display_awake_service.dart';

void main() {
  test(
    'enables and disables display-awake through the wakelock client',
    () async {
      final client = _FakeWakelockClient();
      final service = WakelockDisplayAwakeService(client: client);

      expect(await service.setAwake(true), isTrue);
      expect(await service.setAwake(false), isTrue);

      expect(client.toggles, <bool>[true, false]);
    },
  );

  test('logs failures instead of throwing', () async {
    final logger = _FakeDisplayAwakeLogger();
    final service = WakelockDisplayAwakeService(
      client: _ThrowingWakelockClient(),
      logWarning: logger.call,
    );

    expect(await service.setAwake(true), isFalse);

    expect(logger.messages, hasLength(1));
    expect(logger.messages.single, contains('enable'));
  });
}

class _FakeWakelockClient implements WakelockClient {
  final List<bool> toggles = <bool>[];

  @override
  Future<void> toggle({required bool enable}) async {
    toggles.add(enable);
  }
}

class _ThrowingWakelockClient implements WakelockClient {
  @override
  Future<void> toggle({required bool enable}) {
    throw StateError('toggle failed');
  }
}

class _FakeDisplayAwakeLogger {
  final List<String> messages = <String>[];

  void call(String message, {Object? error, StackTrace? stackTrace}) {
    messages.add(message);
  }
}
