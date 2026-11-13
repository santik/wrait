import 'package:flutter/widgets.dart';

/// Stable widget keys for the calendar screen, used by widget tests.
abstract final class CalendarTestKeys {
  static const ValueKey<String> back = ValueKey('calendarBackButton');
  static const ValueKey<String> monthTitle = ValueKey('calendarMonthTitle');
  static const ValueKey<String> previousMonth =
      ValueKey('calendarPreviousMonthButton');
  static const ValueKey<String> nextMonth = ValueKey('calendarNextMonthButton');
  static const ValueKey<String> today = ValueKey('calendarTodayButton');
  static const ValueKey<String> grid = ValueKey('calendarGrid');
  static const ValueKey<String> inlineList = ValueKey('calendarInlineList');
  static const ValueKey<String> emptyMonth = ValueKey('calendarEmptyMonth');
  static const ValueKey<String> loadError = ValueKey('calendarLoadError');
}
