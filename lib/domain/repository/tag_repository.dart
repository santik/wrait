import '../model/tag.dart';

abstract interface class TagRepository {
  static const int maxTags = 10;
  static const int maxTagNameLength = 15;

  Stream<List<Tag>> watchAllTags();
  Stream<List<Tag>> watchTagsForEntry(int entryId);
  Future<List<Tag>> getTagsForEntry(int entryId);
  Future<List<Tag>> getAllTags();
  Future<Map<int, int>> getTagCounts();
  Future<Tag> createTag(String name);
  Future<Tag?> findTagByName(String name);
  Future<void> deleteTag(int id);
  Future<void> setTagsForEntry(int entryId, List<int> tagIds);
}
