import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../domain/model/entry.dart';
import '../../domain/model/supported_language.dart';
import '../../l10n/app_localizations.dart';
import 'locale_date_format.dart';

class EntryListTimestampLabel {
  const EntryListTimestampLabel({
    required this.shortWeekday,
    required this.date,
    required this.time,
  });

  final String shortWeekday;
  final String date;
  final String time;

  String get displayLabel => '$shortWeekday, $date · $time';
}

EntryListTimestampLabel formatEntryListTimestamp({
  required int createdAt,
  required Locale locale,
}) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt).toLocal();

  return formatWithLocaleFallback(
    locale,
    (localeName) => EntryListTimestampLabel(
      shortWeekday: DateFormat('EEE', localeName).format(dateTime),
      date: DateFormat.yMd(localeName).format(dateTime),
      time: DateFormat.jm(localeName).format(dateTime),
    ),
  );
}

String entryListPreviewText(Entry entry, AppLocalizations l10n) {
  final body = entry.displayText;
  if (body.isNotEmpty) {
    return _firstNonBlankLine(body);
  }

  if (entryListIsAudioOnlyDraft(entry)) {
    return l10n.entryListAudioDraftPreview;
  }

  return '';
}

String entryListLanguageLabel(String languageCode) {
  return supportedLanguageDisplayName(languageCode) ?? languageCode;
}

bool entryListIsAudioOnlyDraft(Entry entry) {
  final audioPath = entry.audioPath;
  return entry.type == EntryType.draft &&
      audioPath != null &&
      audioPath.isNotEmpty &&
      (entry.cleanedText == null || entry.cleanedText!.trim().isEmpty) &&
      entry.rawTranscript.trim().isEmpty;
}

String _firstNonBlankLine(String text) {
  final normalizedText = text.replaceAll('\r\n', '\n');
  for (final line in normalizedText.split('\n')) {
    if (line.trim().isNotEmpty) {
      return line;
    }
  }

  return '';
}
