import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef DisplayAwakeLogWarning = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

abstract interface class DisplayAwakeService {
  Future<bool> setAwake(bool enabled);
}

abstract interface class WakelockClient {
  Future<void> toggle({required bool enable});
}

class WakelockPlusClient implements WakelockClient {
  const WakelockPlusClient();

  @override
  Future<void> toggle({required bool enable}) {
    return WakelockPlus.toggle(enable: enable);
  }
}

final displayAwakeWarningLoggerProvider = Provider<DisplayAwakeLogWarning>((
  ref,
) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'DisplayAwake',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final wakelockClientProvider = Provider<WakelockClient>((ref) {
  return const WakelockPlusClient();
});

final displayAwakeServiceProvider = Provider<DisplayAwakeService>((ref) {
  return WakelockDisplayAwakeService(
    client: ref.read(wakelockClientProvider),
    logWarning: ref.read(displayAwakeWarningLoggerProvider),
  );
});

class WakelockDisplayAwakeService implements DisplayAwakeService {
  WakelockDisplayAwakeService({required this._client, this._logWarning});

  final WakelockClient _client;
  final DisplayAwakeLogWarning? _logWarning;

  @override
  Future<bool> setAwake(bool enabled) async {
    try {
      await _client.toggle(enable: enabled);
      return true;
    } catch (error, stackTrace) {
      _logWarning?.call(
        'Failed to ${enabled ? 'enable' : 'disable'} display-awake behavior.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
