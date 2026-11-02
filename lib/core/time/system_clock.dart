abstract interface class Clock {
  int now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int now() => DateTime.now().millisecondsSinceEpoch;
}
