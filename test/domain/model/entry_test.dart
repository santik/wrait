import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/entry.dart';

void main() {
  test('copyWith preserves and replaces EntryType as requested', () {
    const draftEntry = Entry(
      id: 1,
      rawTranscript: 'raw',
      cleanedText: null,
      type: EntryType.draft,
      language: 'en-US',
      createdAt: 123,
      wordCount: 1,
      audioPath: '/tmp/audio.m4a',
    );

    final savedEntry = draftEntry.copyWith(
      type: EntryType.saved,
      cleanedText: 'clean',
      clearAudioPath: true,
    );

    expect(savedEntry.type, EntryType.saved);
    expect(savedEntry.cleanedText, 'clean');
    expect(savedEntry.audioPath, isNull);
    expect(draftEntry.type, EntryType.draft);
  });

  test('EntryType.tryParse accepts supported values and rejects others', () {
    expect(EntryType.tryParse('draft'), EntryType.draft);
    expect(EntryType.tryParse('saved'), EntryType.saved);
    expect(EntryType.tryParse('unknown'), isNull);
  });
}
