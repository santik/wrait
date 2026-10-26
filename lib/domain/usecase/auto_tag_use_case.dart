import '../../data/api/backend_results.dart';
import '../model/tag.dart';
import '../repository/tag_repository.dart';

const autoTagProbabilityThreshold = 0.75;

typedef AutoTagWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

class AutoTagUseCase {
  AutoTagUseCase({required this.tagRepository, required this.logWarning});

  final TagRepository tagRepository;
  final AutoTagWarningLogger logWarning;

  Future<void> call({
    required int entryId,
    required Future<TagTextResult> tagResultFuture,
    required List<Tag> userTags,
  }) async {
    try {
      final tagResult = await tagResultFuture;
      if (tagResult is! TagTextSuccess) {
        logWarning('Auto-tag skipped for entry $entryId: tag API call failed.');
        return;
      }

      // Filter tags above threshold
      final matchingTagNames = tagResult.tags
          .where((t) => t.probability > autoTagProbabilityThreshold)
          .map((t) => t.tag)
          .toSet();

      if (matchingTagNames.isEmpty) return;

      // Map tag names to IDs
      final nameToId = {for (final t in userTags) t.name.toLowerCase(): t.id};
      final autoTagIds = <int>{};
      for (final name in matchingTagNames) {
        final id = nameToId[name.toLowerCase()];
        if (id != null) autoTagIds.add(id);
      }

      if (autoTagIds.isEmpty) return;

      // Merge with existing tags (union)
      final existingTags = await tagRepository.getTagsForEntry(entryId);
      final existingIds = existingTags.map((t) => t.id).toSet();
      final unionIds = {...existingIds, ...autoTagIds};

      if (unionIds.length == existingIds.length) return; // nothing new

      await tagRepository.setTagsForEntry(entryId, unionIds.toList());
    } catch (error, stackTrace) {
      logWarning(
        'Auto-tag failed for entry $entryId.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
