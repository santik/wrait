import '../../domain/model/tag.dart';
import '../../domain/repository/tag_repository.dart';
import 'local_entry_database.dart';

class TagRepositoryImpl implements TagRepository {
  TagRepositoryImpl({required this.tagDao});

  final TagDao tagDao;

  @override
  Stream<List<Tag>> watchAllTags() {
    return tagDao.watchAllTags().map(
      (rows) => rows.map(mapTagRecord).toList(growable: false),
    );
  }

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) {
    return tagDao.watchTagsForEntry(entryId).map(
      (rows) => rows.map(mapTagRecord).toList(growable: false),
    );
  }

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) async {
    final rows = await tagDao.getTagsForEntry(entryId);
    return rows.map(mapTagRecord).toList(growable: false);
  }

  @override
  Future<List<Tag>> getAllTags() async {
    final rows = await tagDao.getAllTags();
    return rows.map(mapTagRecord).toList(growable: false);
  }

  @override
  Future<Map<int, int>> getTagCounts() {
    return tagDao.getTagEntryCounts();
  }

  @override
  Future<Tag> createTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Tag name must not be empty');
    }
    if (trimmed.length > TagRepository.maxTagNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'Tag name must not exceed ${TagRepository.maxTagNameLength} characters',
      );
    }

    final existing = await tagDao.findTagByName(trimmed);
    if (existing != null) {
      throw StateError('A tag with name "$trimmed" already exists');
    }

    final tagCount = await tagDao.getTagCount();
    if (tagCount >= TagRepository.maxTags) {
      throw StateError(
        'Cannot create tag: maximum of ${TagRepository.maxTags} tags reached',
      );
    }

    final id = await tagDao.insertTag(
      TagRecordsCompanion.insert(name: trimmed),
    );
    return Tag(id: id, name: trimmed);
  }

  @override
  Future<Tag?> findTagByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final record = await tagDao.findTagByName(trimmed);
    return record == null ? null : mapTagRecord(record);
  }

  @override
  Future<void> deleteTag(int id) async {
    final affected = await tagDao.deleteTagById(id);
    if (affected == 0) {
      throw StateError('Tag with id $id not found');
    }
  }

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) {
    return tagDao.setTagsForEntry(entryId, tagIds);
  }

  static Tag mapTagRecord(TagRecord row) {
    return Tag(id: row.id, name: row.name);
  }
}
