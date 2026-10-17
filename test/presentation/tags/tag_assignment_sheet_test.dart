import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/presentation/tags/tag_assignment_sheet.dart';

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
    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    expect(find.text('No tags yet'), findsOneWidget);
  });

  testWidgets('shows all tags as filter chips', (tester) async {
    tagRepository.setTags([
      const Tag(id: 1, name: 'work'),
      const Tag(id: 2, name: 'travel'),
    ]);

    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    expect(find.text('work'), findsOneWidget);
    expect(find.text('travel'), findsOneWidget);
    expect(find.byKey(const ValueKey('assignTag-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('assignTag-2')), findsOneWidget);
  });

  testWidgets('selected tags are marked as selected', (tester) async {
    tagRepository.setTags([
      const Tag(id: 1, name: 'work'),
      const Tag(id: 2, name: 'travel'),
    ]);
    tagRepository.setEntryTags(1, {1});

    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    final workChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('assignTag-1')),
    );
    final travelChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('assignTag-2')),
    );
    expect(workChip.selected, isTrue);
    expect(travelChip.selected, isFalse);
  });

  testWidgets('tapping a chip toggles its selection', (tester) async {
    tagRepository.setTags([
      const Tag(id: 1, name: 'work'),
      const Tag(id: 2, name: 'travel'),
    ]);

    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    await tester.tap(find.byKey(const ValueKey('assignTag-1')));
    await tester.pumpAndSettle();

    final workChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('assignTag-1')),
    );
    expect(workChip.selected, isTrue);
    expect(tagRepository.lastSetEntryId, 1);
    expect(tagRepository.lastSetTagIds, contains(1));
  });

  testWidgets('shows limit-reached message when at max tags', (tester) async {
    tagRepository.setTags([
      for (var i = 1; i <= TagRepository.maxTags; i++)
        Tag(id: i, name: 'tag$i'),
    ]);

    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    expect(
      find.text('Tag limit reached (${TagRepository.maxTags})'),
      findsOneWidget,
    );
  });

  testWidgets('done button is shown', (tester) async {
    await _pump(tester, tagRepository: tagRepository, entryId: 1);

    expect(find.text('Done'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeTagRepository tagRepository,
  required int entryId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagRepositoryProvider.overrideWithValue(tagRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: TagAssignmentSheet(entryId: entryId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTagRepository implements TagRepository {
  final _tagsController = StreamController<List<Tag>>.broadcast();
  var _tags = <Tag>[];
  final _entryTags = <int, Set<int>>{};
  var _nextId = 100;

  int? lastSetEntryId;
  List<int>? lastSetTagIds;

  void setTags(List<Tag> tags) {
    _tags = List.of(tags);
    _nextId = tags.fold<int>(
          0,
          (max, t) => t.id > max ? t.id : max,
        ) +
        1;
    _tagsController.add(_tags);
  }

  void setEntryTags(int entryId, Set<int> tagIds) {
    _entryTags[entryId] = tagIds;
  }

  Future<void> dispose() => _tagsController.close();

  @override
  Stream<List<Tag>> watchAllTags() async* {
    yield _tags;
    yield* _tagsController.stream;
  }

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) async* {
    final ids = _entryTags[entryId] ?? const {};
    yield _tags.where((t) => ids.contains(t.id)).toList();
  }

  @override
  Future<List<Tag>> getAllTags() async => _tags;

  @override
  Future<Map<int, int>> getTagCounts() async => {};

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
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    lastSetEntryId = entryId;
    lastSetTagIds = tagIds;
    _entryTags[entryId] = tagIds.toSet();
  }
}
