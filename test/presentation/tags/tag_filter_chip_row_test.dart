import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wrait/data/entries/tag_providers.dart';
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/presentation/tags/tag_filter_chip_row.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  late _FakeTagRepository tagRepository;

  setUp(() {
    tagRepository = _FakeTagRepository();
  });

  tearDown(() async {
    await tagRepository.dispose();
  });

  testWidgets('renders nothing when no tags exist', (tester) async {
    await _pump(tester, tagRepository: tagRepository);

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('shows All chip plus tag chips and manage button', (
    tester,
  ) async {
    tagRepository.setTags([
      const Tag(id: 1, name: 'work'),
      const Tag(id: 2, name: 'travel'),
    ]);

    await _pump(tester, tagRepository: tagRepository);

    expect(find.byKey(const ValueKey('tagFilterAll')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagFilter-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagFilter-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagFilterManage')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(find.text('travel'), findsOneWidget);
  });

  testWidgets('All chip is selected by default', (tester) async {
    tagRepository.setTags([const Tag(id: 1, name: 'work')]);

    await _pump(tester, tagRepository: tagRepository);

    final allChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilterAll')),
    );
    final workChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilter-1')),
    );
    expect(allChip.selected, isTrue);
    expect(workChip.selected, isFalse);
  });

  testWidgets('tapping a tag chip selects it and deselects All', (
    tester,
  ) async {
    tagRepository.setTags([const Tag(id: 1, name: 'work')]);

    await _pump(tester, tagRepository: tagRepository);

    await tester.tap(find.byKey(const ValueKey('tagFilter-1')));
    await tester.pumpAndSettle();

    final allChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilterAll')),
    );
    final workChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilter-1')),
    );
    expect(allChip.selected, isFalse);
    expect(workChip.selected, isTrue);
  });

  testWidgets('tapping a selected tag deselects it back to All', (
    tester,
  ) async {
    tagRepository.setTags([const Tag(id: 1, name: 'work')]);

    await _pump(tester, tagRepository: tagRepository);

    await tester.tap(find.byKey(const ValueKey('tagFilter-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tagFilter-1')));
    await tester.pumpAndSettle();

    final allChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilterAll')),
    );
    final workChip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('tagFilter-1')),
    );
    expect(allChip.selected, isTrue);
    expect(workChip.selected, isFalse);
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
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(
                body: TagFilterChipRow(),
              ),
            ),
            GoRoute(
              path: '/tags',
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

  void setTags(List<Tag> tags) {
    _tags = List.of(tags);
    _tagsController.add(_tags);
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
  Future<List<Tag>> getAllTags() async => _tags;

  @override
  Future<Map<int, int>> getTagCounts() async => {};

  @override
  Future<Tag> createTag(String name) async {
    throw UnimplementedError();
  }

  @override
  Future<Tag?> findTagByName(String name) async => null;

  @override
  Future<void> deleteTag(int id) async {}

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {}
}
