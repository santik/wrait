import 'package:wrait/core/time/system_clock.dart';

class FakeClock implements Clock {
  FakeClock(this.currentTimeMs);

  int currentTimeMs;

  @override
  int now() => currentTimeMs;

  void advance(Duration duration) {
    currentTimeMs += duration.inMilliseconds;
  }
}
