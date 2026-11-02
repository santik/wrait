import 'package:wrait/core/time/monotonic_clock.dart';

class FakeMonotonicClock implements MonotonicClock {
  FakeMonotonicClock(this.currentTimeMs);

  int currentTimeMs;

  @override
  int now() => currentTimeMs;

  void advance(Duration duration) {
    currentTimeMs += duration.inMilliseconds;
  }
}
