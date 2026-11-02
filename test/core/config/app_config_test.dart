import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses defaults when values are omitted', () {
      final config = AppConfig.fromValues();

      expect(config.backendUrl, AppConfig.defaultBackendUrl);
      expect(config.proxySecret, isEmpty);
      expect(
        config.recordingHardCapMs,
        int.parse(AppConfig.defaultRecordingHardCapMs),
      );
      expect(config.wiredashProjectId, isEmpty);
      expect(config.wiredashSecret, isEmpty);
      expect(config.wiredashEnvironment, AppConfig.defaultWiredashEnvironment);
      expect(config.wiredashConfigured, isFalse);
      expect(config.debugDeviceId, isEmpty);
      expect(config.isDebugDeviceConfigured, isFalse);
    });

    test('applies explicit override values', () {
      final config = AppConfig.fromValues(
        backendUrl: 'https://example.com/api',
        proxySecret: 'proxy-secret',
        recordingHardCapMs: '60000',
        wiredashProjectId: 'project-id',
        wiredashSecret: 'sdk-secret',
        wiredashEnvironment: 'staging',
      );

      expect(config.backendUrl, 'https://example.com/api');
      expect(config.backendUri.host, 'example.com');
      expect(config.proxySecret, 'proxy-secret');
      expect(config.recordingHardCapMs, 60000);
      expect(config.wiredashProjectId, 'project-id');
      expect(config.wiredashSecret, 'sdk-secret');
      expect(config.wiredashEnvironment, 'staging');
      expect(config.wiredashConfigured, isTrue);
    });

    test('treats partial Wiredash configuration as unavailable', () {
      final projectOnly = AppConfig.fromValues(wiredashProjectId: 'project');
      final secretOnly = AppConfig.fromValues(wiredashSecret: 'secret');

      expect(projectOnly.wiredashConfigured, isFalse);
      expect(secretOnly.wiredashConfigured, isFalse);
    });

    test('sets debugDeviceId and reports it as configured', () {
      final config = AppConfig.fromValues(debugDeviceId: 'abc123');

      expect(config.debugDeviceId, 'abc123');
      expect(config.isDebugDeviceConfigured, isTrue);
    });

    test('treats an empty debugDeviceId as not configured', () {
      expect(AppConfig.fromValues().isDebugDeviceConfigured, isFalse);
      expect(
        AppConfig.fromValues(debugDeviceId: '').isDebugDeviceConfigured,
        isFalse,
      );
    });

    test('trims a whitespace-only debugDeviceId to empty', () {
      final config = AppConfig.fromValues(debugDeviceId: '   ');

      expect(config.debugDeviceId, isEmpty);
      expect(config.isDebugDeviceConfigured, isFalse);
    });

    test('rejects a non-positive recording hard cap', () {
      expect(
        () => AppConfig.fromValues(recordingHardCapMs: '0'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig.fromValues(recordingHardCapMs: '-1'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
