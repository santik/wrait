import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/presentation/tags/manage_tags_screen.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late _FakeTagRepository tagRepository;

  setUp(() {
    tagRepository = _FakeTagRepository();
  });

  tearDown(() async {
    await tagRepository.dispose();
  });

  testWidgets('shows empty state when no tags exist', (tester) async {
    await _pump(tester, tagRepository: tagRepository);

    expect(find.byKey(const ValueKey('manageTagsEmptyState')), findsOneWidget);
    expect(find.text('No tags yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('manageTagsNameField')), findsOneWidget);
  });

  testWidgets('lists tags with entry counts', (tester) async {
    tagRepository.setTags([
      const Tag(id: 1, name: 'work'),
      const Tag(id: 2, name: 'travel'),
    ]);
    tagRepository.setTagCounts({1: 5, 2: 0});

    await _pump(tester, tagRepository: tagRepository);

    expect(find.text('work'), findsOneWidget);
    expect(find.text('travel'), findsOneWidget);
    expect(find.text('5 entries'), findsOneWidget);
    expect(find.text('0 entries'), findsOneWidget);
    expect(find.byKey(const ValueKey('manageTagDelete-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('manageTagDelete-2')), findsOneWidget);
  });

  testWidgets('creates a new tag via add button', (tester) async {
    await _pump(tester, tagRepository: tagRepository);

    final field = find.byKey(const ValueKey('manageTagsNameField'));
    await tester.enterText(field, 'ideas');
    await tester.tap(find.byKey(const ValueKey('manageTagsAddButton')));
    await tester.pumpAndSettle();

    expect(find.text('ideas'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('manageTagsEmptyState')),
      findsNothing,
    );
  });

  testWidgets('shows limit-reached message when at max tags', (tester) async {
    tagRepository.setTags([
      for (var i = 1; i <= TagRepository.maxTags; i++)
        Tag(id: i, name: 'tag$i'),
    ]);

    await _pump(tester, tagRepository: tagRepository);

    expect(find.byKey(const ValueKey('manageTagsNameField')), findsNothing);
    expect(
      find.text('Tag limit reached (${TagRepository.maxTags})'),
      findsOneWidget,
    );
  });

  testWidgets('delete button shows confirmation dialog', (tester) async {
    tagRepository.setTags([const Tag(id: 1, name: 'work')]);

    await _pump(tester, tagRepository: tagRepository);

    await tester.tap(find.byKey(const ValueKey('manageTagDelete-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete tag?'), findsOneWidget);
    expect(
      find.text('This tag will be removed from all entries.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeTagRepository tagRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagRepositoryProvider.overrideWithValue(tagRepository),
      ],
      child: MaterialApp.router(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/tags',
          routes: [
            GoRoute(
              path: '/tags',
              builder: (_, __) => const ManageTagsScreen(),
            ),
            GoRoute(
              path: '/entries',
              builder: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTagRepository implements TagRepository {
  final _tagsController = StreamController<List<Tag>>.broadcast();
  var _tags = <Tag>[];
  var _tagCounts = <int, int>{};
  var _nextId = 100;

  void setTags(List<Tag> tags) {
    _tags = List.of(tags);
    _nextId = tags.fold<int>(
          0,
          (max, t) => t.id > max ? t.id : max,
        ) +
        1;
    _tagsController.add(_tags);
  }

  void setTagCounts(Map<int, int> counts) {
    _tagCounts = Map.of(counts);
  }

  Future<void> dispose() => _tagsController.close();

  @override
  Stream<List<Tag>> watchAllTags() async* {
    yield _tags;
    yield* _tagsController.stream;
  }

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) async* {
    yield const [];
  }

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) async => const [];

  @override
  Future<List<Tag>> getAllTags() async => _tags;

  @override
  Future<Map<int, int>> getTagCounts() async => _tagCounts;

  @override
  Future<Tag> createTag(String name) async {
    final tag = Tag(id: _nextId++, name: name.trim());
    _tags = [..._tags, tag];
    _tagsController.add(_tags);
    return tag;
  }

  @override
  Future<Tag?> findTagByName(String name) async {
    final lower = name.toLowerCase();
    for (final tag in _tags) {
      if (tag.name.toLowerCase() == lower) return tag;
    }
    return null;
  }

  @override
  Future<void> deleteTag(int id) async {
    _tags = _tags.where((t) => t.id != id).toList();
    _tagsController.add(_tags);
  }

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {}
}
