import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/model/entry.dart';
import '../../l10n/app_localizations.dart';
import 'locale_date_format.dart';

class EntryDetailDateLabel {
  const EntryDetailDateLabel({required this.weekday, required this.date});

  final String weekday;
  final String date;
}

class EntryDetailShareTimestampLabel {
  const EntryDetailShareTimestampLabel({
    required this.weekday,
    required this.date,
    required this.time,
  });

  final String weekday;
  final String date;
  final String time;

  String get displayLabel => '$weekday, $date · $time';
}

const String entryDetailShareSectionSeparator = '\n\n';

String entryDetailDisplayText(Entry entry) => entry.displayText;

bool entryDetailIsReadable(Entry? entry) {
  if (entry == null) {
    return false;
  }

  return entryDetailDisplayText(entry).trim().isNotEmpty;
}

EntryDetailDateLabel formatEntryDetailDate({
  required int createdAt,
  required Locale locale,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();

  return formatWithLocaleFallback(
    locale,
    (localeName) => EntryDetailDateLabel(
      weekday: DateFormat('EEEE', localeName).format(dateTime),
      date: DateFormat.yMMMMd(localeName).format(dateTime),
    ),
  );
}

String formatEntryDetailShareTimestamp({
  required int createdAt,
  required Locale locale,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();

  return formatWithLocaleFallback(
    locale,
    (localeName) => EntryDetailShareTimestampLabel(
      weekday: DateFormat('EEEE', localeName).format(dateTime),
      date: DateFormat.yMMMMd(localeName).format(dateTime),
      time: DateFormat.jm(localeName).format(dateTime),
    ),
  ).displayLabel;
}

String formatEntryWordCount(int wordCount, AppLocalizations l10n) {
  return l10n.wordCount(wordCount);
}

