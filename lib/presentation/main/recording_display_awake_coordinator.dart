import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/display/display_awake_service.dart';
import '../app_lock/app_lock_controller.dart';
import 'recording_state.dart';

class RecordingDisplayAwakeCoordinator {
  RecordingDisplayAwakeCoordinator({
    required this._service,
    required this._recordingState,
    required this._lifecycleState,
    required this._appLockState,
  }) : _desiredAwake = false,
       _appliedAwake = false {
    _recompute();
  }

  final DisplayAwakeService _service;
  RecordingState _recordingState;
  AppLifecycleState _lifecycleState;
  AppLockState _appLockState;
  bool _desiredAwake;
  bool _appliedAwake;
  Future<void> _operationQueue = Future<void>.value();
  bool _isDisposed = false;

  void updateRecordingState(RecordingState recordingState) {
    if (_isDisposed) {
      return;
    }
    if (_recordingState == recordingState && !_needsSync) {
      return;
    }
    _recordingState = recordingState;
    _recompute();
  }

  void updateLifecycleState(AppLifecycleState lifecycleState) {
    if (_isDisposed) {
      return;
    }
    if (_lifecycleState == lifecycleState && !_needsSync) {
      return;
    }
    _lifecycleState = lifecycleState;
    _recompute();
  }

  void updateAppLockState(AppLockState appLockState) {
    if (_isDisposed) {
      return;
    }
    if (_appLockState == appLockState && !_needsSync) {
      return;
    }
    _appLockState = appLockState;
    _recompute();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _desiredAwake = false;
    _queueSync();
  }

  void _recompute() {
    if (_isDisposed) {
      return;
    }
    final shouldKeepAwake =
        _lifecycleState == AppLifecycleState.resumed &&
        !_appLockState.isLocked &&
        _recordingState is RecordingListening;
    if (_desiredAwake == shouldKeepAwake && !_needsSync) {
      return;
    }

    _desiredAwake = shouldKeepAwake;
    _queueSync();
  }

  bool get _needsSync => _appliedAwake != _desiredAwake;

  // Serialize platform calls so the last desired state wins without
  // overlapping wakelock toggles.
  void _queueSync() {
    _operationQueue = _operationQueue.then((_) async {
      if (!_needsSync) {
        return;
      }

      final target = _desiredAwake;
      final didApply = await _setAwakeSafely(target);
      if (didApply) {
        _appliedAwake = target;
      }
    });
  }

  Future<bool> _setAwakeSafely(bool enabled) async {
    try {
      return await _service.setAwake(enabled);
    } catch (_) {
      return false;
    }
  }
}
