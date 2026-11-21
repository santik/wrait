part of 'local_entry_database.dart';

@DriftAccessor(tables: [EntryRecords])
class EntryDao extends DatabaseAccessor<LocalEntryDatabase>
    with _$EntryDaoMixin {
  EntryDao(super.attachedDatabase);

  Stream<List<EntryRecord>> watchAllEntries() {
    return (select(
      entryRecords,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).watch();
  }

  Stream<EntryRecord?> watchEntryById(int id) {
    return (select(
      entryRecords,
    )..where((table) => table.id.equals(id))).watchSingleOrNull();
  }

  Future<EntryRecord?> getEntryById(int id) {
    return (select(
      entryRecords,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<List<EntryRecord>> getPendingDrafts() {
    return (select(entryRecords)
          ..where((table) => table.type.equals('draft'))
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
        .get();
  }

  Future<List<EntryRecord>> getStaleDraftsOlderThan(int cutoffTimestamp) {
    return (select(entryRecords)..where(
          (table) =>
              table.type.equals('draft') &
              table.createdAt.isSmallerThanValue(cutoffTimestamp),
        ))
        .get();
  }

  Future<bool> hasEntryOnDate(int startOfDayMs, int endOfDayMs) async {
    final query = selectOnly(entryRecords)
      ..addColumns([entryRecords.id])
      ..where(
        entryRecords.createdAt.isBiggerOrEqualValue(startOfDayMs) &
            entryRecords.createdAt.isSmallerThanValue(endOfDayMs),
      )
      ..limit(1);
    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<int> insertEntry(EntryRecordsCompanion entry) {
    return into(entryRecords).insert(entry);
  }

  Future<List<int>> insertEntries(List<EntryRecordsCompanion> entries) async {
    return transaction(() async {
      final ids = <int>[];
      for (final entry in entries) {
        ids.add(await into(entryRecords).insert(entry));
      }
      return ids;
    });
  }

  Future<int> updateEditedCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
      ),
    );
  }

  Future<int> updateWithCleanedText(int id, String cleanedText, int wordCount) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
        type: const Value('saved'),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        wordCount: Value(wordCount),
        type: const Value('draft'),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        wordCount: Value(wordCount),
        type: const Value('draft'),
        language: Value(language),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(
        rawTranscript: Value(rawTranscript),
        cleanedText: Value(cleanedText),
        wordCount: Value(wordCount),
        type: const Value('saved'),
        audioPath: const Value(null),
      ),
    );
  }

  Future<int> updateEntryLanguage(int id, String language) {
    return (update(entryRecords)..where((table) => table.id.equals(id))).write(
      EntryRecordsCompanion(language: Value(language)),
    );
  }

  Future<int> deleteEntryById(int id) {
    return (delete(entryRecords)..where((table) => table.id.equals(id))).go();
  }

  /// Deletes empty, audio-less `saved` entries: rows left behind when a manual
  /// compose session was abandoned without the discard-on-exit cleanup running
  /// (e.g. the app was killed mid-compose). A valid saved entry always has body
  /// text, so this only targets blank placeholders.
  ///
  /// Body fields are matched after trimming so a draft containing only
  /// whitespace (persisted mid-compose as e.g. `'   '`) is still collected and
  /// does not leave a permanently-unreadable ghost row behind.
  Future<int> deleteEmptySavedEntries() {
    return (delete(entryRecords)..where(
          (table) =>
              table.type.equals('saved') &
              table.audioPath.isNull() &
              table.rawTranscript.trim().equals('') &
              (table.cleanedText.isNull() | table.cleanedText.trim().equals('')),
        ))
        .go();
  }

  Future<int> deleteStaleDraftsOlderThan(int cutoffTimestamp) {
    return (delete(entryRecords)..where(
          (table) =>
              table.type.equals('draft') &
              table.createdAt.isSmallerThanValue(cutoffTimestamp),
        ))
        .go();
  }
}
