import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/tag_providers.dart';
import '../../domain/model/tag.dart';
import '../../domain/repository/tag_repository.dart';

final manageTagsAllTagsProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAllTags();
});

final manageTagsCountsProvider = FutureProvider.autoDispose<Map<int, int>>((
  ref,
) {
  return ref.watch(tagRepositoryProvider).getTagCounts();
});

final manageTagsControllerProvider =
    NotifierProvider.autoDispose<ManageTagsController, ManageTagsState>(
      ManageTagsController.new,
    );

class ManageTagsState {
  const ManageTagsState({this.error});
  final String? error;

  ManageTagsState copyWith({String? error, bool clearError = false}) {
    return ManageTagsState(error: clearError ? null : error ?? this.error);
  }
}

class ManageTagsController extends Notifier<ManageTagsState> {
  @override
  ManageTagsState build() => const ManageTagsState();

  TagRepository get _tagRepository => ref.read(tagRepositoryProvider);

  Future<bool> createTag(String name) async {
    try {
      await _tagRepository.createTag(name);
      state = state.copyWith(clearError: true);
      return true;
    } on ArgumentError catch (e) {
      state = state.copyWith(error: e.message?.toString());
      return false;
    } on StateError catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    }
  }

  Future<bool> deleteTag(int id) async {
    try {
      await _tagRepository.deleteTag(id);
      // Invalidate counts after deletion
      ref.invalidate(manageTagsCountsProvider);
      state = state.copyWith(clearError: true);
      return true;
    } catch (e, st) {
      developer.log(
        'Failed to delete tag',
        name: 'ManageTagsController',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(error: 'Could not delete tag');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
