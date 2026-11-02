import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/tag_providers.dart';
import '../../domain/model/tag.dart';
import '../../domain/repository/tag_repository.dart';

final tagAssignmentControllerProvider = NotifierProvider.family
    .autoDispose<TagAssignmentController, TagAssignmentState, int>(
      TagAssignmentController.new,
    );

class TagAssignmentState {
  const TagAssignmentState({
    this.allTags = const [],
    this.selectedTagIds = const {},
    this.error,
  });

  final List<Tag> allTags;
  final Set<int> selectedTagIds;
  final String? error;

  TagAssignmentState copyWith({
    List<Tag>? allTags,
    Set<int>? selectedTagIds,
    String? error,
    bool clearError = false,
  }) {
    return TagAssignmentState(
      allTags: allTags ?? this.allTags,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class TagAssignmentController extends Notifier<TagAssignmentState> {
  TagAssignmentController(this._entryId);

  final int _entryId;

  @override
  TagAssignmentState build() {
    _loadTags();
    return const TagAssignmentState();
  }

  TagRepository get _tagRepository => ref.read(tagRepositoryProvider);

  Future<void> _loadTags() async {
    try {
      final allTags = await _tagRepository.getAllTags();
      final entryTags = await _tagRepository.watchTagsForEntry(_entryId).first;
      if (!ref.mounted) return;
      state = state.copyWith(
        allTags: allTags,
        selectedTagIds: entryTags.map((t) => t.id).toSet(),
        clearError: true,
      );
    } catch (e, st) {
      developer.log(
        'Failed to load tags',
        name: 'TagAssignmentController',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> toggleTag(int tagId) async {
    final selected = Set<int>.from(state.selectedTagIds);
    if (selected.contains(tagId)) {
      selected.remove(tagId);
    } else {
      selected.add(tagId);
    }
    state = state.copyWith(selectedTagIds: selected, clearError: true);

    try {
      await _tagRepository.setTagsForEntry(_entryId, selected.toList());
    } catch (e, st) {
      developer.log(
        'Failed to set tags',
        name: 'TagAssignmentController',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> createAndAssignTag(String name) async {
    try {
      final tag = await _tagRepository.createTag(name);
      final allTags = await _tagRepository.getAllTags();
      if (!ref.mounted) return;
      final selected = Set<int>.from(state.selectedTagIds)..add(tag.id);
      state = state.copyWith(
        allTags: allTags,
        selectedTagIds: selected,
        clearError: true,
      );
      await _tagRepository.setTagsForEntry(_entryId, selected.toList());
    } on ArgumentError catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e.message?.toString());
    } on StateError catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: e.message);
    }
  }
}
