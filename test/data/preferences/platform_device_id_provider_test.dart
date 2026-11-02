import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/preferences/platform_device_id_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    MethodChannelPlatformDeviceIdProvider.channelName,
  );

  late MethodChannelPlatformDeviceIdProvider provider;

  setUp(() {
    provider = const MethodChannelPlatformDeviceIdProvider(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the value supplied by the method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(
            call.method,
            MethodChannelPlatformDeviceIdProvider.getDeviceIdMethod,
          );
          return 'android-device-id-123';
        });

    await expectLater(
      provider.getPlatformDeviceId(),
      completion('android-device-id-123'),
    );
  });

  test('returns null when the method channel returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);

    await expectLater(provider.getPlatformDeviceId(), completion(isNull));
  });

  test('returns null when the method channel returns blank', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => '   ');

    await expectLater(provider.getPlatformDeviceId(), completion(isNull));
  });

  test(
    'returns null when the method channel throws a platform exception',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'device_id_unavailable'),
          );

      await expectLater(provider.getPlatformDeviceId(), completion(isNull));
    },
  );

  test('returns null when the method channel is missing', () async {
    await expectLater(provider.getPlatformDeviceId(), completion(isNull));
  });
}
