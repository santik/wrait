import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

abstract interface class DeviceSecuritySettingsOpener {
  Future<bool> openDeviceSecuritySettings();
}

abstract interface class AppSettingsOpener {
  Future<bool> openAppSettings();
}

abstract interface class AndroidSecuritySettingsChannel {
  Future<bool?> openSecuritySettings();
}

class PermissionHandlerAppSettingsOpener implements AppSettingsOpener {
  @override
  Future<bool> openAppSettings() {
    return permission_handler.openAppSettings();
  }
}

class MethodChannelAndroidSecuritySettingsChannel
    implements AndroidSecuritySettingsChannel {
  MethodChannelAndroidSecuritySettingsChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'wrait/app_lock';

  final MethodChannel _channel;

  @override
  Future<bool?> openSecuritySettings() {
    return _channel.invokeMethod<bool>('openSecuritySettings');
  }
}

typedef IsAndroidPlatform = bool Function();

class BestEffortDeviceSecuritySettingsOpener
    implements DeviceSecuritySettingsOpener {
  BestEffortDeviceSecuritySettingsOpener({
    AndroidSecuritySettingsChannel? androidChannel,
    AppSettingsOpener? appSettingsOpener,
    IsAndroidPlatform? isAndroidPlatform,
  }) : _androidChannel =
           androidChannel ?? MethodChannelAndroidSecuritySettingsChannel(),
       _appSettingsOpener =
           appSettingsOpener ?? PermissionHandlerAppSettingsOpener(),
       _isAndroidPlatform = isAndroidPlatform ?? _defaultIsAndroidPlatform;

  final AndroidSecuritySettingsChannel _androidChannel;
  final AppSettingsOpener _appSettingsOpener;
  final IsAndroidPlatform _isAndroidPlatform;

  @override
  Future<bool> openDeviceSecuritySettings() async {
    if (_isAndroidPlatform()) {
      try {
        final opened = await _androidChannel.openSecuritySettings();
        if (opened ?? false) {
          return true;
        }
      } on PlatformException {
        // Fall back to app settings below.
      } on MissingPluginException {
        // Fall back to app settings below.
      }
    }

    return _appSettingsOpener.openAppSettings();
  }
}

bool _defaultIsAndroidPlatform() => Platform.isAndroid;
