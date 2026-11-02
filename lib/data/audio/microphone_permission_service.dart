import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum MicrophoneAccessState { granted, denied, permanentlyDenied, restricted }

abstract interface class MicrophonePermissionService {
  Future<MicrophoneAccessState> getMicrophoneAccess();
  Future<MicrophoneAccessState> requestMicrophoneAccess();
  Future<bool> openMicrophonePermissionSettings();
}

abstract interface class MicrophonePermissionClient {
  Future<PermissionStatus> get status;
  Future<PermissionStatus> requestAccess();
  Future<bool> openSettings();
}

class PermissionHandlerMicrophonePermissionClient
    implements MicrophonePermissionClient {
  @override
  Future<PermissionStatus> get status => Permission.microphone.status;

  @override
  Future<bool> openSettings() => openAppSettings();

  @override
  Future<PermissionStatus> requestAccess() => Permission.microphone.request();
}

typedef IsIosPlatform = bool Function();

class PermissionHandlerMicrophonePermissionService
    implements MicrophonePermissionService {
  PermissionHandlerMicrophonePermissionService({
    MicrophonePermissionClient? permissionClient,
    IsIosPlatform? isIosPlatform,
  }) : _permissionClient =
           permissionClient ?? PermissionHandlerMicrophonePermissionClient(),
       _isIosPlatform = isIosPlatform ?? _defaultIsIosPlatform;

  final MicrophonePermissionClient _permissionClient;
  final IsIosPlatform _isIosPlatform;
  bool _hasRequestedAccess = false;

  @override
  Future<MicrophoneAccessState> getMicrophoneAccess() async {
    return _resolveState(
      await _permissionClient.status,
      source: _PermissionResolutionSource.statusCheck,
    );
  }

  @override
  Future<MicrophoneAccessState> requestMicrophoneAccess() async {
    final currentState = await getMicrophoneAccess();
    if (currentState
        case MicrophoneAccessState.granted ||
            MicrophoneAccessState.permanentlyDenied ||
            MicrophoneAccessState.restricted) {
      return currentState;
    }

    _hasRequestedAccess = true;
    return _resolveState(
      await _permissionClient.requestAccess(),
      source: _PermissionResolutionSource.requestResult,
    );
  }

  @override
  Future<bool> openMicrophonePermissionSettings() =>
      _permissionClient.openSettings();

  MicrophoneAccessState _resolveState(
    PermissionStatus status, {
    required _PermissionResolutionSource source,
  }) {
    if (_isIosPlatform() &&
        status == PermissionStatus.denied &&
        (_hasRequestedAccess ||
            source == _PermissionResolutionSource.requestResult)) {
      return MicrophoneAccessState.permanentlyDenied;
    }

    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => MicrophoneAccessState.granted,
      PermissionStatus.permanentlyDenied =>
        MicrophoneAccessState.permanentlyDenied,
      PermissionStatus.restricted => MicrophoneAccessState.restricted,
      PermissionStatus.denied => MicrophoneAccessState.denied,
    };
  }
}

bool _defaultIsIosPlatform() => Platform.isIOS;

enum _PermissionResolutionSource { statusCheck, requestResult }
