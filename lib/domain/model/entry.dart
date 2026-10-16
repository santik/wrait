import 'tag.dart';

enum EntryType {
  draft,
  saved;

  static EntryType? tryParse(String rawValue) {
    for (final value in values) {
      if (value.name == rawValue) {
        return value;
      }
    }

    return null;
  }
}

class Entry {
  const Entry({
    this.id = 0,
    required this.rawTranscript,
    this.cleanedText,
    required this.type,
    required this.language,
    required this.createdAt,
    required this.wordCount,
    this.audioPath,
    this.tags = const [],
  });

  final int id;
  final String rawTranscript;
  final String? cleanedText;
  final EntryType type;
  final String language;
  final int createdAt;
  final int wordCount;
  final String? audioPath;
  final List<Tag> tags;

  Entry copyWith({
    int? id,
    String? rawTranscript,
    String? cleanedText,
    bool clearCleanedText = false,
    EntryType? type,
    String? language,
    int? createdAt,
    int? wordCount,
    String? audioPath,
    bool clearAudioPath = false,
    List<Tag>? tags,
  }) {
    return Entry(
      id: id ?? this.id,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      cleanedText: clearCleanedText ? null : cleanedText ?? this.cleanedText,
      type: type ?? this.type,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      wordCount: wordCount ?? this.wordCount,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Entry &&
            other.id == id &&
            other.rawTranscript == rawTranscript &&
            other.cleanedText == cleanedText &&
            other.type == type &&
            other.language == language &&
            other.createdAt == createdAt &&
            other.wordCount == wordCount &&
            other.audioPath == audioPath &&
            _listEquals(other.tags, tags));
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawTranscript,
    cleanedText,
    type,
    language,
    createdAt,
    wordCount,
    audioPath,
    Object.hashAll(tags),
  );

  static bool _listEquals(List<Tag> a, List<Tag> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
