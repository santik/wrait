// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_entry_database.dart';

// ignore_for_file: type=lint
class $EntryRecordsTable extends EntryRecords
    with TableInfo<$EntryRecordsTable, EntryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rawTranscriptMeta = const VerificationMeta(
    'rawTranscript',
  );
  @override
  late final GeneratedColumn<String> rawTranscript = GeneratedColumn<String>(
    'raw_transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleanedTextMeta = const VerificationMeta(
    'cleanedText',
  );
  @override
  late final GeneratedColumn<String> cleanedText = GeneratedColumn<String>(
    'cleaned_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (type IN (\'draft\', \'saved\'))',
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rawTranscript,
    cleanedText,
    type,
    language,
    createdAt,
    wordCount,
    audioPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('raw_transcript')) {
      context.handle(
        _rawTranscriptMeta,
        rawTranscript.isAcceptableOrUnknown(
          data['raw_transcript']!,
          _rawTranscriptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawTranscriptMeta);
    }
    if (data.containsKey('cleaned_text')) {
      context.handle(
        _cleanedTextMeta,
        cleanedText.isAcceptableOrUnknown(
          data['cleaned_text']!,
          _cleanedTextMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rawTranscript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_transcript'],
      )!,
      cleanedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cleaned_text'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
    );
  }

  @override
  $EntryRecordsTable createAlias(String alias) {
    return $EntryRecordsTable(attachedDatabase, alias);
  }
}

class EntryRecord extends DataClass implements Insertable<EntryRecord> {
  final int id;
  final String rawTranscript;
  final String? cleanedText;
  final String type;
  final String language;
  final int createdAt;
  final int wordCount;
  final String? audioPath;
  const EntryRecord({
    required this.id,
    required this.rawTranscript,
    this.cleanedText,
    required this.type,
    required this.language,
    required this.createdAt,
    required this.wordCount,
    this.audioPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['raw_transcript'] = Variable<String>(rawTranscript);
    if (!nullToAbsent || cleanedText != null) {
      map['cleaned_text'] = Variable<String>(cleanedText);
    }
    map['type'] = Variable<String>(type);
    map['language'] = Variable<String>(language);
    map['created_at'] = Variable<int>(createdAt);
    map['word_count'] = Variable<int>(wordCount);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    return map;
  }

  EntryRecordsCompanion toCompanion(bool nullToAbsent) {
    return EntryRecordsCompanion(
      id: Value(id),
      rawTranscript: Value(rawTranscript),
      cleanedText: cleanedText == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanedText),
      type: Value(type),
      language: Value(language),
      createdAt: Value(createdAt),
      wordCount: Value(wordCount),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
    );
  }

  factory EntryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRecord(
      id: serializer.fromJson<int>(json['id']),
      rawTranscript: serializer.fromJson<String>(json['rawTranscript']),
      cleanedText: serializer.fromJson<String?>(json['cleanedText']),
      type: serializer.fromJson<String>(json['type']),
      language: serializer.fromJson<String>(json['language']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rawTranscript': serializer.toJson<String>(rawTranscript),
      'cleanedText': serializer.toJson<String?>(cleanedText),
      'type': serializer.toJson<String>(type),
      'language': serializer.toJson<String>(language),
      'createdAt': serializer.toJson<int>(createdAt),
      'wordCount': serializer.toJson<int>(wordCount),
      'audioPath': serializer.toJson<String?>(audioPath),
    };
  }

  EntryRecord copyWith({
    int? id,
    String? rawTranscript,
    Value<String?> cleanedText = const Value.absent(),
    String? type,
    String? language,
    int? createdAt,
    int? wordCount,
    Value<String?> audioPath = const Value.absent(),
  }) => EntryRecord(
    id: id ?? this.id,
    rawTranscript: rawTranscript ?? this.rawTranscript,
    cleanedText: cleanedText.present ? cleanedText.value : this.cleanedText,
    type: type ?? this.type,
    language: language ?? this.language,
    createdAt: createdAt ?? this.createdAt,
    wordCount: wordCount ?? this.wordCount,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
  );
  EntryRecord copyWithCompanion(EntryRecordsCompanion data) {
    return EntryRecord(
      id: data.id.present ? data.id.value : this.id,
      rawTranscript: data.rawTranscript.present
          ? data.rawTranscript.value
          : this.rawTranscript,
      cleanedText: data.cleanedText.present
          ? data.cleanedText.value
          : this.cleanedText,
      type: data.type.present ? data.type.value : this.type,
      language: data.language.present ? data.language.value : this.language,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRecord(')
          ..write('id: $id, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('type: $type, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('wordCount: $wordCount, ')
          ..write('audioPath: $audioPath')
          ..write(')'))
        .toString();
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
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRecord &&
          other.id == this.id &&
          other.rawTranscript == this.rawTranscript &&
          other.cleanedText == this.cleanedText &&
          other.type == this.type &&
          other.language == this.language &&
          other.createdAt == this.createdAt &&
          other.wordCount == this.wordCount &&
          other.audioPath == this.audioPath);
}

class EntryRecordsCompanion extends UpdateCompanion<EntryRecord> {
  final Value<int> id;
  final Value<String> rawTranscript;
  final Value<String?> cleanedText;
  final Value<String> type;
  final Value<String> language;
  final Value<int> createdAt;
  final Value<int> wordCount;
  final Value<String?> audioPath;
  const EntryRecordsCompanion({
    this.id = const Value.absent(),
    this.rawTranscript = const Value.absent(),
    this.cleanedText = const Value.absent(),
    this.type = const Value.absent(),
    this.language = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.audioPath = const Value.absent(),
  });
  EntryRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String rawTranscript,
    this.cleanedText = const Value.absent(),
    required String type,
    required String language,
    required int createdAt,
    this.wordCount = const Value.absent(),
    this.audioPath = const Value.absent(),
  }) : rawTranscript = Value(rawTranscript),
       type = Value(type),
       language = Value(language),
       createdAt = Value(createdAt);
  static Insertable<EntryRecord> custom({
    Expression<int>? id,
    Expression<String>? rawTranscript,
    Expression<String>? cleanedText,
    Expression<String>? type,
    Expression<String>? language,
    Expression<int>? createdAt,
    Expression<int>? wordCount,
    Expression<String>? audioPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rawTranscript != null) 'raw_transcript': rawTranscript,
      if (cleanedText != null) 'cleaned_text': cleanedText,
      if (type != null) 'type': type,
      if (language != null) 'language': language,
      if (createdAt != null) 'created_at': createdAt,
      if (wordCount != null) 'word_count': wordCount,
      if (audioPath != null) 'audio_path': audioPath,
    });
  }

  EntryRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? rawTranscript,
    Value<String?>? cleanedText,
    Value<String>? type,
    Value<String>? language,
    Value<int>? createdAt,
    Value<int>? wordCount,
    Value<String?>? audioPath,
  }) {
    return EntryRecordsCompanion(
      id: id ?? this.id,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      cleanedText: cleanedText ?? this.cleanedText,
      type: type ?? this.type,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      wordCount: wordCount ?? this.wordCount,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rawTranscript.present) {
      map['raw_transcript'] = Variable<String>(rawTranscript.value);
    }
    if (cleanedText.present) {
      map['cleaned_text'] = Variable<String>(cleanedText.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('type: $type, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('wordCount: $wordCount, ')
          ..write('audioPath: $audioPath')
          ..write(')'))
        .toString();
  }
}

class $TagRecordsTable extends TagRecords
    with TableInfo<$TagRecordsTable, TagRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE COLLATE NOCASE',
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagRecordsTable createAlias(String alias) {
    return $TagRecordsTable(attachedDatabase, alias);
  }
}

class TagRecord extends DataClass implements Insertable<TagRecord> {
  final int id;
  final String name;
  const TagRecord({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagRecordsCompanion toCompanion(bool nullToAbsent) {
    return TagRecordsCompanion(id: Value(id), name: Value(name));
  }

  factory TagRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRecord(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  TagRecord copyWith({int? id, String? name}) =>
      TagRecord(id: id ?? this.id, name: name ?? this.name);
  TagRecord copyWithCompanion(TagRecordsCompanion data) {
    return TagRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRecord(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRecord && other.id == this.id && other.name == this.name);
}

class TagRecordsCompanion extends UpdateCompanion<TagRecord> {
  final Value<int> id;
  final Value<String> name;
  const TagRecordsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  TagRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<TagRecord> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  TagRecordsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return TagRecordsCompanion(id: id ?? this.id, name: name ?? this.name);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagRecordsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $EntryTagRecordsTable extends EntryTagRecords
    with TableInfo<$EntryTagRecordsTable, EntryTagRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryTagRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES entries(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES tags(id) ON DELETE CASCADE',
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryTagRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, tagId};
  @override
  EntryTagRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryTagRecord(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $EntryTagRecordsTable createAlias(String alias) {
    return $EntryTagRecordsTable(attachedDatabase, alias);
  }
}

class EntryTagRecord extends DataClass implements Insertable<EntryTagRecord> {
  final int entryId;
  final int tagId;
  const EntryTagRecord({required this.entryId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<int>(entryId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  EntryTagRecordsCompanion toCompanion(bool nullToAbsent) {
    return EntryTagRecordsCompanion(
      entryId: Value(entryId),
      tagId: Value(tagId),
    );
  }

  factory EntryTagRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryTagRecord(
      entryId: serializer.fromJson<int>(json['entryId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<int>(entryId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  EntryTagRecord copyWith({int? entryId, int? tagId}) => EntryTagRecord(
    entryId: entryId ?? this.entryId,
    tagId: tagId ?? this.tagId,
  );
  EntryTagRecord copyWithCompanion(EntryTagRecordsCompanion data) {
    return EntryTagRecord(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagRecord(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryTagRecord &&
          other.entryId == this.entryId &&
          other.tagId == this.tagId);
}

class EntryTagRecordsCompanion extends UpdateCompanion<EntryTagRecord> {
  final Value<int> entryId;
  final Value<int> tagId;
  final Value<int> rowid;
  const EntryTagRecordsCompanion({
    this.entryId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryTagRecordsCompanion.insert({
    required int entryId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       tagId = Value(tagId);
  static Insertable<EntryTagRecord> custom({
    Expression<int>? entryId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryTagRecordsCompanion copyWith({
    Value<int>? entryId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return EntryTagRecordsCompanion(
      entryId: entryId ?? this.entryId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagRecordsCompanion(')
          ..write('entryId: $entryId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalEntryDatabase extends GeneratedDatabase {
  _$LocalEntryDatabase(QueryExecutor e) : super(e);
  $LocalEntryDatabaseManager get managers => $LocalEntryDatabaseManager(this);
  late final $EntryRecordsTable entryRecords = $EntryRecordsTable(this);
  late final $TagRecordsTable tagRecords = $TagRecordsTable(this);
  late final $EntryTagRecordsTable entryTagRecords = $EntryTagRecordsTable(
    this,
  );
  late final EntryDao entryDao = EntryDao(this as LocalEntryDatabase);
  late final TagDao tagDao = TagDao(this as LocalEntryDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    entryRecords,
    tagRecords,
    entryTagRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$EntryRecordsTableCreateCompanionBuilder =
    EntryRecordsCompanion Function({
      Value<int> id,
      required String rawTranscript,
      Value<String?> cleanedText,
      required String type,
      required String language,
      required int createdAt,
      Value<int> wordCount,
      Value<String?> audioPath,
    });
typedef $$EntryRecordsTableUpdateCompanionBuilder =
    EntryRecordsCompanion Function({
      Value<int> id,
      Value<String> rawTranscript,
      Value<String?> cleanedText,
      Value<String> type,
      Value<String> language,
      Value<int> createdAt,
      Value<int> wordCount,
      Value<String?> audioPath,
    });

final class $$EntryRecordsTableReferences
    extends
        BaseReferences<_$LocalEntryDatabase, $EntryRecordsTable, EntryRecord> {
  $$EntryRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntryTagRecordsTable, List<EntryTagRecord>>
  _entryTagRecordsRefsTable(_$LocalEntryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.entryTagRecords,
        aliasName: 'entries__id__entry_tags__entry_id',
      );

  $$EntryTagRecordsTableProcessedTableManager get entryTagRecordsRefs {
    final manager = $$EntryTagRecordsTableTableManager(
      $_db,
      $_db.entryTagRecords,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _entryTagRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EntryRecordsTableFilterComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entryTagRecordsRefs(
    Expression<bool> Function($$EntryTagRecordsTableFilterComposer f) f,
  ) {
    final $$EntryTagRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTagRecords,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagRecordsTableFilterComposer(
            $db: $db,
            $table: $db.entryTagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntryRecordsTableOrderingComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryRecordsTableAnnotationComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  Expression<T> entryTagRecordsRefs<T extends Object>(
    Expression<T> Function($$EntryTagRecordsTableAnnotationComposer a) f,
  ) {
    final $$EntryTagRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTagRecords,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryTagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntryRecordsTableTableManager
    extends
        RootTableManager<
          _$LocalEntryDatabase,
          $EntryRecordsTable,
          EntryRecord,
          $$EntryRecordsTableFilterComposer,
          $$EntryRecordsTableOrderingComposer,
          $$EntryRecordsTableAnnotationComposer,
          $$EntryRecordsTableCreateCompanionBuilder,
          $$EntryRecordsTableUpdateCompanionBuilder,
          (EntryRecord, $$EntryRecordsTableReferences),
          EntryRecord,
          PrefetchHooks Function({bool entryTagRecordsRefs})
        > {
  $$EntryRecordsTableTableManager(
    _$LocalEntryDatabase db,
    $EntryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> rawTranscript = const Value.absent(),
                Value<String?> cleanedText = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
              }) => EntryRecordsCompanion(
                id: id,
                rawTranscript: rawTranscript,
                cleanedText: cleanedText,
                type: type,
                language: language,
                createdAt: createdAt,
                wordCount: wordCount,
                audioPath: audioPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String rawTranscript,
                Value<String?> cleanedText = const Value.absent(),
                required String type,
                required String language,
                required int createdAt,
                Value<int> wordCount = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
              }) => EntryRecordsCompanion.insert(
                id: id,
                rawTranscript: rawTranscript,
                cleanedText: cleanedText,
                type: type,
                language: language,
                createdAt: createdAt,
                wordCount: wordCount,
                audioPath: audioPath,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryRecordsTable, EntryRecord>(table),
                  $$EntryRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryTagRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (entryTagRecordsRefs) db.entryTagRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entryTagRecordsRefs)
                    await $_getPrefetchedData<
                      EntryRecord,
                      $EntryRecordsTable,
                      EntryTagRecord
                    >(
                      currentTable: table,
                      referencedTable: $$EntryRecordsTableReferences
                          ._entryTagRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EntryRecordsTableReferences(
                            db,
                            table,
                            p0,
                          ).entryTagRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.entryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EntryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalEntryDatabase,
      $EntryRecordsTable,
      EntryRecord,
      $$EntryRecordsTableFilterComposer,
      $$EntryRecordsTableOrderingComposer,
      $$EntryRecordsTableAnnotationComposer,
      $$EntryRecordsTableCreateCompanionBuilder,
      $$EntryRecordsTableUpdateCompanionBuilder,
      (EntryRecord, $$EntryRecordsTableReferences),
      EntryRecord,
      PrefetchHooks Function({bool entryTagRecordsRefs})
    >;
typedef $$TagRecordsTableCreateCompanionBuilder = TagRecordsCompanion Function({
  Value<int> id,
  required String name,
});
typedef $$TagRecordsTableUpdateCompanionBuilder = TagRecordsCompanion Function({
  Value<int> id,
  Value<String> name,
});

final class $$TagRecordsTableReferences
    extends BaseReferences<_$LocalEntryDatabase, $TagRecordsTable, TagRecord> {
  $$TagRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntryTagRecordsTable, List<EntryTagRecord>>
  _entryTagRecordsRefsTable(_$LocalEntryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.entryTagRecords,
        aliasName: 'tags__id__entry_tags__tag_id',
      );

  $$EntryTagRecordsTableProcessedTableManager get entryTagRecordsRefs {
    final manager = $$EntryTagRecordsTableTableManager(
      $_db,
      $_db.entryTagRecords,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _entryTagRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagRecordsTableFilterComposer
    extends Composer<_$LocalEntryDatabase, $TagRecordsTable> {
  $$TagRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entryTagRecordsRefs(
    Expression<bool> Function($$EntryTagRecordsTableFilterComposer f) f,
  ) {
    final $$EntryTagRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTagRecords,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagRecordsTableFilterComposer(
            $db: $db,
            $table: $db.entryTagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagRecordsTableOrderingComposer
    extends Composer<_$LocalEntryDatabase, $TagRecordsTable> {
  $$TagRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagRecordsTableAnnotationComposer
    extends Composer<_$LocalEntryDatabase, $TagRecordsTable> {
  $$TagRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> entryTagRecordsRefs<T extends Object>(
    Expression<T> Function($$EntryTagRecordsTableAnnotationComposer a) f,
  ) {
    final $$EntryTagRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entryTagRecords,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryTagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagRecordsTableTableManager
    extends
        RootTableManager<
          _$LocalEntryDatabase,
          $TagRecordsTable,
          TagRecord,
          $$TagRecordsTableFilterComposer,
          $$TagRecordsTableOrderingComposer,
          $$TagRecordsTableAnnotationComposer,
          $$TagRecordsTableCreateCompanionBuilder,
          $$TagRecordsTableUpdateCompanionBuilder,
          (TagRecord, $$TagRecordsTableReferences),
          TagRecord,
          PrefetchHooks Function({bool entryTagRecordsRefs})
        > {
  $$TagRecordsTableTableManager(_$LocalEntryDatabase db, $TagRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => TagRecordsCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) => TagRecordsCompanion.insert(id: id, name: name),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagRecordsTable, TagRecord>(table),
                  $$TagRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryTagRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (entryTagRecordsRefs) db.entryTagRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entryTagRecordsRefs)
                    await $_getPrefetchedData<
                      TagRecord,
                      $TagRecordsTable,
                      EntryTagRecord
                    >(
                      currentTable: table,
                      referencedTable: $$TagRecordsTableReferences
                          ._entryTagRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagRecordsTableReferences(
                            db,
                            table,
                            p0,
                          ).entryTagRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalEntryDatabase,
      $TagRecordsTable,
      TagRecord,
      $$TagRecordsTableFilterComposer,
      $$TagRecordsTableOrderingComposer,
      $$TagRecordsTableAnnotationComposer,
      $$TagRecordsTableCreateCompanionBuilder,
      $$TagRecordsTableUpdateCompanionBuilder,
      (TagRecord, $$TagRecordsTableReferences),
      TagRecord,
      PrefetchHooks Function({bool entryTagRecordsRefs})
    >;
typedef $$EntryTagRecordsTableCreateCompanionBuilder =
    EntryTagRecordsCompanion Function({
      required int entryId,
      required int tagId,
      Value<int> rowid,
    });
typedef $$EntryTagRecordsTableUpdateCompanionBuilder =
    EntryTagRecordsCompanion Function({
      Value<int> entryId,
      Value<int> tagId,
      Value<int> rowid,
    });

final class $$EntryTagRecordsTableReferences
    extends
        BaseReferences<
          _$LocalEntryDatabase,
          $EntryTagRecordsTable,
          EntryTagRecord
        > {
  $$EntryTagRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EntryRecordsTable _entryIdTable(_$LocalEntryDatabase db) =>
      db.entryRecords.createAlias('entry_tags__entry_id__entries__id');

  $$EntryRecordsTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<int>('entry_id')!;

    final manager = $$EntryRecordsTableTableManager(
      $_db,
      $_db.entryRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagRecordsTable _tagIdTable(_$LocalEntryDatabase db) =>
      db.tagRecords.createAlias('entry_tags__tag_id__tags__id');

  $$TagRecordsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagRecordsTableTableManager(
      $_db,
      $_db.tagRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntryTagRecordsTableFilterComposer
    extends Composer<_$LocalEntryDatabase, $EntryTagRecordsTable> {
  $$EntryTagRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntryRecordsTableFilterComposer get entryId {
    final $$EntryRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entryRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryRecordsTableFilterComposer(
            $db: $db,
            $table: $db.entryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagRecordsTableFilterComposer get tagId {
    final $$TagRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagRecordsTableFilterComposer(
            $db: $db,
            $table: $db.tagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagRecordsTableOrderingComposer
    extends Composer<_$LocalEntryDatabase, $EntryTagRecordsTable> {
  $$EntryTagRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntryRecordsTableOrderingComposer get entryId {
    final $$EntryRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entryRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.entryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagRecordsTableOrderingComposer get tagId {
    final $$TagRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.tagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagRecordsTableAnnotationComposer
    extends Composer<_$LocalEntryDatabase, $EntryTagRecordsTable> {
  $$EntryTagRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$EntryRecordsTableAnnotationComposer get entryId {
    final $$EntryRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entryRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagRecordsTableAnnotationComposer get tagId {
    final $$TagRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tagRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.tagRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagRecordsTableTableManager
    extends
        RootTableManager<
          _$LocalEntryDatabase,
          $EntryTagRecordsTable,
          EntryTagRecord,
          $$EntryTagRecordsTableFilterComposer,
          $$EntryTagRecordsTableOrderingComposer,
          $$EntryTagRecordsTableAnnotationComposer,
          $$EntryTagRecordsTableCreateCompanionBuilder,
          $$EntryTagRecordsTableUpdateCompanionBuilder,
          (EntryTagRecord, $$EntryTagRecordsTableReferences),
          EntryTagRecord,
          PrefetchHooks Function({bool entryId, bool tagId})
        > {
  $$EntryTagRecordsTableTableManager(
    _$LocalEntryDatabase db,
    $EntryTagRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryTagRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryTagRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryTagRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> entryId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryTagRecordsCompanion(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int entryId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => EntryTagRecordsCompanion.insert(
                entryId: entryId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryTagRecordsTable, EntryTagRecord>(table),
                  $$EntryTagRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.entryId,
                        referencedTable: $$EntryTagRecordsTableReferences
                            ._entryIdTable(db),
                        referencedColumn: $$EntryTagRecordsTableReferences
                            ._entryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$EntryTagRecordsTableReferences
                            ._tagIdTable(db),
                        referencedColumn: $$EntryTagRecordsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntryTagRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalEntryDatabase,
      $EntryTagRecordsTable,
      EntryTagRecord,
      $$EntryTagRecordsTableFilterComposer,
      $$EntryTagRecordsTableOrderingComposer,
      $$EntryTagRecordsTableAnnotationComposer,
      $$EntryTagRecordsTableCreateCompanionBuilder,
      $$EntryTagRecordsTableUpdateCompanionBuilder,
      (EntryTagRecord, $$EntryTagRecordsTableReferences),
      EntryTagRecord,
      PrefetchHooks Function({bool entryId, bool tagId})
    >;

class $LocalEntryDatabaseManager {
  final _$LocalEntryDatabase _db;
  $LocalEntryDatabaseManager(this._db);
  $$EntryRecordsTableTableManager get entryRecords =>
      $$EntryRecordsTableTableManager(_db, _db.entryRecords);
  $$TagRecordsTableTableManager get tagRecords =>
      $$TagRecordsTableTableManager(_db, _db.tagRecords);
  $$EntryTagRecordsTableTableManager get entryTagRecords =>
      $$EntryTagRecordsTableTableManager(_db, _db.entryTagRecords);
}

mixin _$EntryDaoMixin on DatabaseAccessor<LocalEntryDatabase> {
  $EntryRecordsTable get entryRecords => attachedDatabase.entryRecords;
  EntryDaoManager get managers => EntryDaoManager(this);
}

class EntryDaoManager {
  final _$EntryDaoMixin _db;
  EntryDaoManager(this._db);
  $$EntryRecordsTableTableManager get entryRecords =>
      $$EntryRecordsTableTableManager(_db.attachedDatabase, _db.entryRecords);
}

mixin _$TagDaoMixin on DatabaseAccessor<LocalEntryDatabase> {
  $TagRecordsTable get tagRecords => attachedDatabase.tagRecords;
  $EntryRecordsTable get entryRecords => attachedDatabase.entryRecords;
  $EntryTagRecordsTable get entryTagRecords => attachedDatabase.entryTagRecords;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagRecordsTableTableManager get tagRecords =>
      $$TagRecordsTableTableManager(_db.attachedDatabase, _db.tagRecords);
  $$EntryRecordsTableTableManager get entryRecords =>
      $$EntryRecordsTableTableManager(_db.attachedDatabase, _db.entryRecords);
  $$EntryTagRecordsTableTableManager get entryTagRecords =>
      $$EntryTagRecordsTableTableManager(
        _db.attachedDatabase,
        _db.entryTagRecords,
      );
}
