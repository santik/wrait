part of 'local_entry_database.dart';

@DriftAccessor(tables: [TagRecords, EntryTagRecords, EntryRecords])
class TagDao extends DatabaseAccessor<LocalEntryDatabase>
    with _$TagDaoMixin {
  TagDao(super.attachedDatabase);

  Stream<List<TagRecord>> watchAllTags() {
    return (select(tagRecords)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<TagRecord>> getAllTags() {
    return (select(tagRecords)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<int> getTagCount() async {
    final count = countAll();
    final query = selectOnly(tagRecords)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count)!;
  }

  Future<TagRecord?> findTagByName(String name) {
    return (select(tagRecords)
          ..where((t) => t.name.collate(Collate.noCase).equals(name)))
        .getSingleOrNull();
  }

  Future<int> insertTag(TagRecordsCompanion tag) {
    return into(tagRecords).insert(tag);
  }

  Future<int> deleteTagById(int id) {
    return (delete(tagRecords)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<TagRecord>> watchTagsForEntry(int entryId) {
    final query = select(tagRecords).join([
      innerJoin(
        entryTagRecords,
        entryTagRecords.tagId.equalsExp(tagRecords.id),
      ),
    ])
      ..where(entryTagRecords.entryId.equals(entryId))
      ..orderBy([OrderingTerm.asc(tagRecords.name)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(tagRecords)).toList(),
    );
  }

  Future<List<TagRecord>> getTagsForEntry(int entryId) {
    final query = select(tagRecords).join([
      innerJoin(
        entryTagRecords,
        entryTagRecords.tagId.equalsExp(tagRecords.id),
      ),
    ])
      ..where(entryTagRecords.entryId.equals(entryId))
      ..orderBy([OrderingTerm.asc(tagRecords.name)]);

    return query.get().then(
      (rows) => rows.map((row) => row.readTable(tagRecords)).toList(),
    );
  }

  Future<Map<int, int>> getTagEntryCounts() async {
    final tagId = entryTagRecords.tagId;
    final count = countAll();
    final query = selectOnly(entryTagRecords)
      ..addColumns([tagId, count])
      ..groupBy([tagId]);

    final results = await query.get();
    return {
      for (final row in results)
        row.read(tagId)!: row.read(count)!,
    };
  }

  Stream<List<EntryTagRecord>> watchAllAssignments() {
    return select(entryTagRecords).watch();
  }

  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    await transaction(() async {
      await (delete(entryTagRecords)
            ..where((t) => t.entryId.equals(entryId)))
          .go();

      if (tagIds.isNotEmpty) {
        await batch((b) {
          b.insertAll(
            entryTagRecords,
            tagIds
                .map(
                  (tagId) => EntryTagRecordsCompanion.insert(
                    entryId: entryId,
                    tagId: tagId,
                  ),
                )
                .toList(),
          );
        });
      }
    });
  }
}
