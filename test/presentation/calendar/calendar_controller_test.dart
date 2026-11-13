import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/presentation/calendar/calendar_controller.dart';
import 'package:wrait/presentation/entries/entry_list_controller.dart';

import '../../test_doubles/fake_entry_repository.dart';

void main() {
  late FakeEntryRepository repo;

  final entries = [
    fakeEntry(1, DateTime(2026, 11, 11, 9)),
    fakeEntry(2, DateTime(2026, 11, 5, 9)),
    fakeEntry(3, DateTime(2026, 11, 5, 18)),
    fakeEntry(4, DateTime(2026, 10, 15, 9)),
  ];

  setUp(() => repo = FakeEntryRepository(entries));
  tearDown(() => repo.dispose());

  Future<ProviderContainer> makeContainer(DateTime now) async {
    final container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(repo),
        calendarClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.listen(calendarInlineEntriesProvider, (_, _) {});
    container.listen(calendarMonthIndicatorsProvider, (_, _) {});
    await container.read(entryListEntriesProvider.future);
    return container;
  }

  Set<int> inlineIds(ProviderContainer c) =>
      c.read(calendarInlineEntriesProvider).map((e) => e.id).toSet();

  test('inline entries default to the displayed (current) month', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    expect(inlineIds(c), {1, 2, 3});
  });

  test('selecting a day filters the inline list to that day', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    c.read(calendarControllerProvider.notifier).toggleDay(DateTime(2026, 11, 5));
    expect(inlineIds(c), {2, 3});
  });

  test('re-tapping the selected day clears back to the whole month', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    final controller = c.read(calendarControllerProvider.notifier);
    controller.toggleDay(DateTime(2026, 11, 5));
    controller.toggleDay(DateTime(2026, 11, 5));
    expect(c.read(calendarControllerProvider).selectedDay, isNull);
    expect(inlineIds(c), {1, 2, 3});
  });

  test('changing month clears selection and shows that month (D2)', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    final controller = c.read(calendarControllerProvider.notifier);
    controller.toggleDay(DateTime(2026, 11, 5));
    controller.showMonth(DateTime(2026, 10));
    expect(c.read(calendarControllerProvider).selectedDay, isNull);
    expect(inlineIds(c), {4});
  });

  test('goToToday returns to the current month', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    final controller = c.read(calendarControllerProvider.notifier);
    controller.showMonth(DateTime(2026, 10));
    controller.goToToday();
    expect(c.read(calendarControllerProvider).displayedMonth, DateTime(2026, 11));
    expect(inlineIds(c), {1, 2, 3});
  });

  test('derived lists clamp a displayed month past the bounds (P1-2)', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    // A future month is out of range; the inline list clamps to the current
    // month rather than showing an unreachable empty page.
    c.read(calendarControllerProvider.notifier).showMonth(DateTime(2030, 1));
    expect(inlineIds(c), {1, 2, 3});
    expect(
      c.read(calendarMonthIndicatorsProvider).keys,
      containsAll([DateTime(2026, 11, 5), DateTime(2026, 11, 11)]),
    );
  });

  test('clearSelection returns to the whole month (P2-2)', () async {
    final c = await makeContainer(DateTime(2026, 11, 11));
    final controller = c.read(calendarControllerProvider.notifier);
    controller.toggleDay(DateTime(2026, 11, 5));
    expect(inlineIds(c), {2, 3});
    controller.clearSelection();
    expect(c.read(calendarControllerProvider).selectedDay, isNull);
    expect(inlineIds(c), {1, 2, 3});
  });
}
