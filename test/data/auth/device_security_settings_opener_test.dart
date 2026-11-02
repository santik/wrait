import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/auth/device_security_settings_opener.dart';

void main() {
  test('android security settings success does not fall back', () async {
    final appSettingsOpener = _FakeAppSettingsOpener();
    final opener = BestEffortDeviceSecuritySettingsOpener(
      androidChannel: _FakeAndroidSecuritySettingsChannel(result: true),
      appSettingsOpener: appSettingsOpener,
      isAndroidPlatform: () => true,
    );

    expect(await opener.openDeviceSecuritySettings(), isTrue);
    expect(appSettingsOpener.callCount, 0);
  });

  test('android security settings false falls back to app settings', () async {
    final appSettingsOpener = _FakeAppSettingsOpener(result: true);
    final opener = BestEffortDeviceSecuritySettingsOpener(
      androidChannel: _FakeAndroidSecuritySettingsChannel(result: false),
      appSettingsOpener: appSettingsOpener,
      isAndroidPlatform: () => true,
    );

    expect(await opener.openDeviceSecuritySettings(), isTrue);
    expect(appSettingsOpener.callCount, 1);
  });

  test('android channel exception falls back to app settings', () async {
    final appSettingsOpener = _FakeAppSettingsOpener(result: true);
    final opener = BestEffortDeviceSecuritySettingsOpener(
      androidChannel: _FakeAndroidSecuritySettingsChannel(
        error: MissingPluginException(),
      ),
      appSettingsOpener: appSettingsOpener,
      isAndroidPlatform: () => true,
    );

    expect(await opener.openDeviceSecuritySettings(), isTrue);
    expect(appSettingsOpener.callCount, 1);
  });

  test('non-android opens app settings directly', () async {
    final appSettingsOpener = _FakeAppSettingsOpener(result: true);
    final opener = BestEffortDeviceSecuritySettingsOpener(
      androidChannel: _FakeAndroidSecuritySettingsChannel(result: false),
      appSettingsOpener: appSettingsOpener,
      isAndroidPlatform: () => false,
    );

    expect(await opener.openDeviceSecuritySettings(), isTrue);
    expect(appSettingsOpener.callCount, 1);
  });
}

class _FakeAppSettingsOpener implements AppSettingsOpener {
  _FakeAppSettingsOpener({this.result = true});

  final bool result;
  int callCount = 0;

  @override
  Future<bool> openAppSettings() async {
    callCount += 1;
    return result;
  }
}

class _FakeAndroidSecuritySettingsChannel
    implements AndroidSecuritySettingsChannel {
  _FakeAndroidSecuritySettingsChannel({this.result, this.error});

  final bool? result;
  final Object? error;

  @override
  Future<bool?> openSecuritySettings() async {
    if (error != null) {
      throw error!;
    }
    return result;
  }
}
