import 'package:flutter/services.dart';

abstract interface class PlatformDeviceIdProvider {
  Future<String?> getPlatformDeviceId();
}

class MethodChannelPlatformDeviceIdProvider
    implements PlatformDeviceIdProvider {
  const MethodChannelPlatformDeviceIdProvider({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'wrait/preferences';
  static const getDeviceIdMethod = 'getDeviceId';

  final MethodChannel _channel;

  @override
  Future<String?> getPlatformDeviceId() async {
    try {
      final deviceId = await _channel.invokeMethod<String>(getDeviceIdMethod);
      final normalized = deviceId?.trim();
      return normalized == null || normalized.isEmpty ? null : normalized;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
