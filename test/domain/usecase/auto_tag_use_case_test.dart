import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/domain/model/tag.dart';
import 'package:wrait/domain/repository/tag_repository.dart';
import 'package:wrait/domain/usecase/auto_tag_use_case.dart';

void main() {
  late _FakeTagRepository tagRepository;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late AutoTagUseCase useCase;

  const entryId = 42;
  const work = Tag(id: 1, name: 'work');
  const health = Tag(id: 2, name: 'health');
  const travel = Tag(id: 3, name: 'travel');
  const userTags = [work, health, travel];

  setUp(() {
    tagRepository = _FakeTagRepository();
    logMessages = <String>[];
    logErrors = <Object?>[];
    useCase = AutoTagUseCase(
      tagRepository: tagRepository,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  test('assigns tags above the probability threshold', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        _success([('work', 0.8), ('health', 0.9), ('travel', 0.3)]),
      ),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalls, hasLength(1));
    expect(tagRepository.setTagsCalls.single.entryId, entryId);
    expect(tagRepository.setTagsCalls.single.tagIds, unorderedEquals([1, 2]));
    expect(logMessages, isEmpty);
  });

  test('does not assign anything when no tag is above threshold', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        _success([('work', 0.4), ('health', 0.1), ('travel', 0.0)]),
      ),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('tag exactly at the threshold is not assigned', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        _success([('work', autoTagProbabilityThreshold), ('health', 0.76)]),
      ),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalls, hasLength(1));
    expect(tagRepository.setTagsCalls.single.tagIds, [2]);
  });

  test('only an at-threshold tag results in no assignment', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        _success([('work', autoTagProbabilityThreshold)]),
      ),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('tag result failure logs a warning and assigns nothing', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        const backend.TagTextFailure(
          reason: backend.BackendFailureReason.timeout,
        ),
      ),
      userTags: userTags,
    );

    expect(logMessages, isNotEmpty);
    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('tag future that throws logs a warning and assigns nothing', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future<backend.TagTextResult>.error(
        StateError('boom'),
      ),
      userTags: userTags,
    );

    expect(logMessages, isNotEmpty);
    expect(logErrors.whereType<StateError>(), isNotEmpty);
    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('merges auto-detected tags with existing manual tags', () async {
    tagRepository.watchTagsForEntryResult[entryId] = [work];

    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('health', 0.9)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalls, hasLength(1));
    expect(tagRepository.setTagsCalls.single.tagIds, unorderedEquals([1, 2]));
  });

  test('skips tag names that no longer exist in user tags', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(
        _success([('deleted_tag', 0.9), ('travel', 0.8)]),
      ),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalls, hasLength(1));
    expect(tagRepository.setTagsCalls.single.tagIds, [3]);
    expect(logMessages, isEmpty);
  });

  test('does not assign when only unknown tag names are returned', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('deleted_tag', 0.9)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
    expect(logMessages, isEmpty);
  });

  test('matches tag names case-insensitively', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('WORK', 0.9)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalls.single.tagIds, [1]);
  });

  test('does not call setTagsForEntry when nothing new to add', () async {
    tagRepository.watchTagsForEntryResult[entryId] = [work, health];

    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', 0.9)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('assigns tag with probability 1.0', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', 1.0)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isTrue);
    expect(tagRepository.setTagsCalls.single.tagIds, [1]);
  });

  test('assigns tag with probability just above threshold', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', 0.7500001)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isTrue);
    expect(tagRepository.setTagsCalls.single.tagIds, [1]);
  });

  test('does not assign tag with negative probability', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', -0.1)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('does not assign tag with probability 0.0', () async {
    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', 0.0)])),
      userTags: userTags,
    );

    expect(tagRepository.setTagsCalled, isFalse);
  });

  test('logs a warning when setTagsForEntry throws', () async {
    tagRepository.setTagsError = StateError('db failure');

    await useCase(
      entryId: entryId,
      tagResultFuture: Future.value(_success([('work', 0.9)])),
      userTags: userTags,
    );

    expect(logMessages, isNotEmpty);
    expect(logErrors.whereType<StateError>(), isNotEmpty);
  });
}

backend.TagTextSuccess _success(List<(String, double)> tags) {
  return backend.TagTextSuccess(
    tags: [
      for (final (name, probability) in tags)
        backend.TagProbabilityResult(tag: name, probability: probability),
    ],
  );
}

class _SetTagsCall {
  _SetTagsCall(this.entryId, this.tagIds);

  final int entryId;
  final List<int> tagIds;
}

class _FakeTagRepository implements TagRepository {
  final Map<int, List<Tag>> watchTagsForEntryResult = {};
  final List<_SetTagsCall> setTagsCalls = [];
  Object? setTagsError;

  bool get setTagsCalled => setTagsCalls.isNotEmpty;

  @override
  Stream<List<Tag>> watchTagsForEntry(int entryId) {
    return Stream.value(watchTagsForEntryResult[entryId] ?? const <Tag>[]);
  }

  @override
  Future<List<Tag>> getTagsForEntry(int entryId) async {
    return watchTagsForEntryResult[entryId] ?? const <Tag>[];
  }

  @override
  Future<void> setTagsForEntry(int entryId, List<int> tagIds) async {
    final error = setTagsError;
    if (error != null) throw error;
    setTagsCalls.add(_SetTagsCall(entryId, List<int>.of(tagIds)));
  }

  @override
  Stream<List<Tag>> watchAllTags() => throw UnimplementedError();

  @override
  Future<List<Tag>> getAllTags() => throw UnimplementedError();

  @override
  Future<Map<int, int>> getTagCounts() => throw UnimplementedError();

  @override
  Future<Tag> createTag(String name) => throw UnimplementedError();

  @override
  Future<Tag?> findTagByName(String name) => throw UnimplementedError();

  @override
  Future<void> deleteTag(int id) => throw UnimplementedError();
}
