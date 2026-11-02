import 'dart:async';
import 'dart:collection';

import 'package:wrait/data/display/display_awake_service.dart';

class FakeDisplayAwakeService implements DisplayAwakeService {
  FakeDisplayAwakeService({this.autoComplete = true});

  final List<bool> requests = <bool>[];
  final Queue<Completer<bool>> _pendingRequests = Queue<Completer<bool>>();
  final Queue<bool> _queuedResults = Queue<bool>();
  final bool autoComplete;

  int get pendingRequestCount => _pendingRequests.length;

  void enqueueResult(bool result) {
    _queuedResults.add(result);
  }

  @override
  Future<bool> setAwake(bool enabled) {
    requests.add(enabled);
    final completer = Completer<bool>();
    _pendingRequests.add(completer);
    if (autoComplete) {
      final result = _nextResult();
      scheduleMicrotask(() {
        if (completer.isCompleted) {
          return;
        }
        _pendingRequests.remove(completer);
        completer.complete(result);
      });
    }
    return completer.future;
  }

  void completeNext([bool? result]) {
    if (_pendingRequests.isEmpty) {
      throw StateError('No pending display-awake request to complete.');
    }
    _pendingRequests.removeFirst().complete(result ?? _nextResult());
  }

  Future<void> flush() async {
    // The coordinator queues work in a chained future, and autoComplete
    // resolves the fake platform request from a later microtask. The first
    // turn lets the queued sync reach setAwake(); the second lets that fake
    // platform future complete and propagate back into the coordinator.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  bool _nextResult() {
    if (_queuedResults.isEmpty) {
      return true;
    }
    return _queuedResults.removeFirst();
  }
}
