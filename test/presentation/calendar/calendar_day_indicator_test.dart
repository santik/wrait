import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/calendar/calendar_day_indicator.dart';
import 'package:wrait/presentation/calendar/calendar_month_model.dart';

void main() {
  Future<void> pumpMarker(WidgetTester tester, int entryCount) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CalendarDayMarker(
              indicator: CalendarDayIndicator(
                entryCount: entryCount,
                draftOnly: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder dots() => find.descendant(
    of: find.byType(CalendarDayMarker),
    matching: find.byType(Container),
  );

  testWidgets('one entry shows a single dot and no overflow', (tester) async {
    await pumpMarker(tester, 1);
    expect(dots(), findsNWidgets(1));
    expect(find.text('+'), findsNothing);
  });

  testWidgets('three entries show three dots and no overflow', (tester) async {
    await pumpMarker(tester, 3);
    expect(dots(), findsNWidgets(3));
    expect(find.text('+'), findsNothing);
  });

  testWidgets('four entries cap at three dots plus a "+"', (tester) async {
    await pumpMarker(tester, 4);
    expect(dots(), findsNWidgets(3));
    expect(find.text('+'), findsOneWidget);
  });

  testWidgets('many entries still show three dots and a single "+"', (
    tester,
  ) async {
    await pumpMarker(tester, 12);
    expect(dots(), findsNWidgets(3));
    expect(find.text('+'), findsOneWidget);
  });
}
