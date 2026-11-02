abstract interface class MonotonicClock {
  int now();
}

class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock({Stopwatch? stopwatch})
    : _stopwatch = stopwatch ?? Stopwatch() {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
  }

  final Stopwatch _stopwatch;

  @override
  int now() => _stopwatch.elapsedMilliseconds;
}
