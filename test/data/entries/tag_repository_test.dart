import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/entries/tag_repository_impl.dart';
import 'package:wrait/domain/repository/tag_repository.dart';

import '../../test_doubles/fake_secure_storage.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDirectory;
  LocalEntryDatabase? database;
  late TagRepositoryImpl repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('wrait-tag-repo');
    database = await LocalEntryDatabase.open(
      keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
      databaseFile: File(
        '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
      ),
    );
    repository = TagRepositoryImpl(tagDao: database!.tagDao);
  });

  tearDown(() async {
    await database?.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  group('createTag', () {
    test('creates a tag and returns it with an id', () async {
      final tag = await repository.createTag('work');
      expect(tag.id, greaterThan(0));
      expect(tag.name, 'work');
    });

    test('trims whitespace from name', () async {
      final tag = await repository.createTag('  travel  ');
      expect(tag.name, 'travel');
    });

    test('rejects empty name', () async {
      expect(
        () => repository.createTag(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only name', () async {
      expect(
        () => repository.createTag('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects name exceeding max length', () async {
      final longName = 'a' * (TagRepository.maxTagNameLength + 1);
      expect(
        () => repository.createTag(longName),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts name at max length', () async {
      final maxName = 'a' * TagRepository.maxTagNameLength;
      final tag = await repository.createTag(maxName);
      expect(tag.name, maxName);
    });

    test('rejects duplicate name (case-insensitive)', () async {
      await repository.createTag('Work');
      expect(
        () => repository.createTag('work'),
        throwsA(isA<StateError>()),
      );
    });

    test('enforces system limit of ${TagRepository.maxTags} tags', () async {
      for (var i = 0; i < TagRepository.maxTags; i++) {
        await repository.createTag('tag$i');
      }
      expect(
        () => repository.createTag('overflow'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('findTagByName', () {
    test('returns null for non-existent tag', () async {
      final tag = await repository.findTagByName('nope');
      expect(tag, isNull);
    });

    test('returns null for empty name', () async {
      final tag = await repository.findTagByName('');
      expect(tag, isNull);
    });

    test('finds tag case-insensitively', () async {
      final created = await repository.createTag('Travel');
      final found = await repository.findTagByName('travel');
      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.name, 'Travel');
    });
  });

  group('deleteTag', () {
    test('deletes an existing tag', () async {
      final tag = await repository.createTag('temp');
      await repository.deleteTag(tag.id);
      final all = await repository.getAllTags();
      expect(all, isEmpty);
    });

    test('throws when deleting non-existent tag', () async {
      expect(
        () => repository.deleteTag(999),
        throwsA(isA<StateError>()),
      );
    });

    test('frees a slot for a new tag after deletion', () async {
      final tags = <int>[];
      for (var i = 0; i < TagRepository.maxTags; i++) {
        final t = await repository.createTag('tag$i');
        tags.add(t.id);
      }
      await repository.deleteTag(tags.first);
      final newTag = await repository.createTag('replacement');
      expect(newTag.name, 'replacement');
    });
  });

  group('setTagsForEntry', () {
    late int entryId;

    setUp(() async {
      entryId = await database!.entryDao.insertEntry(
        EntryRecordsCompanion.insert(
          rawTranscript: 'test entry',
          type: 'saved',
          language: 'en',
          createdAt: 1700000000000,
        ),
      );
    });

    test('assigns tags to an entry', () async {
      final t1 = await repository.createTag('work');
      final t2 = await repository.createTag('travel');
      await repository.setTagsForEntry(entryId, [t1.id, t2.id]);

      final tags = await database!.tagDao.getTagsForEntry(entryId);
      expect(tags.map((t) => t.name), containsAll(['travel', 'work']));
    });

    test('replaces existing tags', () async {
      final t1 = await repository.createTag('work');
      final t2 = await repository.createTag('travel');
      await repository.setTagsForEntry(entryId, [t1.id]);
      await repository.setTagsForEntry(entryId, [t2.id]);

      final tags = await database!.tagDao.getTagsForEntry(entryId);
      expect(tags, hasLength(1));
      expect(tags.first.name, 'travel');
    });

    test('clears tags when given empty list', () async {
      final t1 = await repository.createTag('work');
      await repository.setTagsForEntry(entryId, [t1.id]);
      await repository.setTagsForEntry(entryId, []);

      final tags = await database!.tagDao.getTagsForEntry(entryId);
      expect(tags, isEmpty);
    });
  });

  group('watchAllTags', () {
    test('emits tags in alphabetical order', () async {
      await repository.createTag('zebra');
      await repository.createTag('apple');

      final tags = await repository.watchAllTags().first;
      expect(tags.map((t) => t.name).toList(), ['apple', 'zebra']);
    });
  });

  group('getTagCounts', () {
    test('returns entry counts per tag', () async {
      final t1 = await repository.createTag('work');
      final t2 = await repository.createTag('travel');

      final e1 = await database!.entryDao.insertEntry(
        EntryRecordsCompanion.insert(
          rawTranscript: 'entry 1',
          type: 'saved',
          language: 'en',
          createdAt: 1700000000000,
        ),
      );
      final e2 = await database!.entryDao.insertEntry(
        EntryRecordsCompanion.insert(
          rawTranscript: 'entry 2',
          type: 'saved',
          language: 'en',
          createdAt: 1700000100000,
        ),
      );

      await repository.setTagsForEntry(e1, [t1.id, t2.id]);
      await repository.setTagsForEntry(e2, [t1.id]);

      final counts = await repository.getTagCounts();
      expect(counts[t1.id], 2);
      expect(counts[t2.id], 1);
    });
  });
}
