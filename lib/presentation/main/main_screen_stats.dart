import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_providers.dart';
import '../../domain/model/entry.dart';
import '../../l10n/app_localizations.dart';

class MainScreenStatsData {
  const MainScreenStatsData({
    required this.entryCount,
    required this.activeDays,
  });

  final int entryCount;
  final int activeDays;

  String displayText(AppLocalizations l10n) => l10n.statsDisplay(
    l10n.statsEntryCount(entryCount),
    l10n.statsActiveDays(activeDays),
  );
}

MainScreenStatsData buildMainScreenStats(Iterable<Entry> entries) {
  final entryList = entries.toList(growable: false);
  final activeDayKeys = entryList.map(_localDayKey).toSet();

  return MainScreenStatsData(
    entryCount: entryList.length,
    activeDays: activeDayKeys.length,
  );
}

final mainScreenStatsProvider = StreamProvider<MainScreenStatsData>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchAllEntries()
      .map(buildMainScreenStats);
});

String _localDayKey(Entry entry) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(entry.createdAt)
      .toLocal();
  return '${dateTime.year}-${dateTime.month}-${dateTime.day}';
}
