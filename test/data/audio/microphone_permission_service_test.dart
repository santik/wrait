import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';

void main() {
  test(
    'iOS keeps the pre-prompt denied state retryable until a request occurs',
    () async {
      final client = _FakeMicrophonePermissionClient(
        status: PermissionStatus.denied,
        requestResult: PermissionStatus.denied,
      );
      final service = PermissionHandlerMicrophonePermissionService(
        permissionClient: client,
        isIosPlatform: () => true,
      );

      expect(await service.getMicrophoneAccess(), MicrophoneAccessState.denied);
    },
  );

  test(
    'iOS denied request result becomes blocked after the first prompt',
    () async {
      final client = _FakeMicrophonePermissionClient(
        status: PermissionStatus.denied,
        requestResult: PermissionStatus.denied,
      );
      final service = PermissionHandlerMicrophonePermissionService(
        permissionClient: client,
        isIosPlatform: () => true,
      );

      expect(
        await service.requestMicrophoneAccess(),
        MicrophoneAccessState.permanentlyDenied,
      );
      expect(
        await service.getMicrophoneAccess(),
        MicrophoneAccessState.permanentlyDenied,
      );
    },
  );

  test('Android uses the request result to detect permanent denial', () async {
    final client = _FakeMicrophonePermissionClient(
      status: PermissionStatus.denied,
      requestResult: PermissionStatus.permanentlyDenied,
    );
    final service = PermissionHandlerMicrophonePermissionService(
      permissionClient: client,
      isIosPlatform: () => false,
    );

    expect(await service.getMicrophoneAccess(), MicrophoneAccessState.denied);
    expect(
      await service.requestMicrophoneAccess(),
      MicrophoneAccessState.permanentlyDenied,
    );
    expect(client.requestCount, 1);
  });

  test(
    'Android Ask every time remains requestable after a denied status',
    () async {
      final client = _FakeMicrophonePermissionClient(
        status: PermissionStatus.denied,
        requestResult: PermissionStatus.granted,
      );
      final service = PermissionHandlerMicrophonePermissionService(
        permissionClient: client,
        isIosPlatform: () => false,
      );

      expect(
        await service.requestMicrophoneAccess(),
        MicrophoneAccessState.granted,
      );
      client._status = PermissionStatus.denied;
      expect(await service.getMicrophoneAccess(), MicrophoneAccessState.denied);
      expect(
        await service.requestMicrophoneAccess(),
        MicrophoneAccessState.granted,
      );
      expect(client.requestCount, 2);
    },
  );

  test('Android denied request result stays retryable', () async {
    final client = _FakeMicrophonePermissionClient(
      status: PermissionStatus.denied,
      requestResult: PermissionStatus.denied,
    );
    final service = PermissionHandlerMicrophonePermissionService(
      permissionClient: client,
      isIosPlatform: () => false,
    );

    expect(
      await service.requestMicrophoneAccess(),
      MicrophoneAccessState.denied,
    );
  });
}

class _FakeMicrophonePermissionClient implements MicrophonePermissionClient {
  _FakeMicrophonePermissionClient({
    required this._status,
    required this.requestResult,
  });

  PermissionStatus _status;
  final PermissionStatus requestResult;
  int requestCount = 0;

  @override
  Future<bool> openSettings() async => true;

  @override
  Future<PermissionStatus> requestAccess() async {
    requestCount += 1;
    _status = requestResult;
    return requestResult;
  }

  @override
  Future<PermissionStatus> get status async => _status;
}
