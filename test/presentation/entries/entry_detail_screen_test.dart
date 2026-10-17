import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/entries/entry_detail_controller.dart';
import 'package:wrait/presentation/entries/entry_detail_formatters.dart';
import 'package:wrait/presentation/entries/entry_share_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  late _TestEntryRepository entryRepository;
  late _TestEntryShareService shareService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    entryRepository = _TestEntryRepository();
    shareService = _TestEntryShareService();
  });

  tearDown(() async {
    await entryRepository.dispose();
  });

  for (final variant in <String, String?>{
    'cleaned text': 'clean text',
    'raw transcript fallback': null,
    'very long cleaned text': List.filled(
      400,
      'A long journal entry preserves every word and line.',
    ).join('\n'),
  }.entries) {
    final cleaned = variant.value;
    testWidgets(
      'body tap matches Edit and supports re-entry (${variant.key})',
      (tester) async {
        entryRepository.seedEntries([
          _entry(id: 1, rawTranscript: 'raw text', cleanedText: cleaned),
        ]);
        await _pumpEntryDetailApp(
          tester,
          entryRepository: entryRepository,
          shareService: shareService,
        );
        final body = find.byKey(const ValueKey('entryDetailReadText'));
        final activate = tester.widget<SelectableText>(body).onTap!;
        // Tap visible text even when the body extends beyond the viewport.
        await tester.tapAt(tester.getTopLeft(body) + const Offset(20, 10));
        // Repeated activation before the read-mode widget is rebuilt must not
        // run the shared toggle's Done branch.
        activate();
        await tester.pumpAndSettle();
        final editor = find.byKey(const ValueKey('entryDetailEditor'));
        var field = tester.widget<TextField>(editor);
        expect(field.controller!.text, cleaned ?? 'raw text');
        expect(field.focusNode!.hasFocus, isTrue);
        expect(
          find.byKey(const ValueKey('entryDetailDoneButton')),
          findsOneWidget,
        );
        final selection = field.controller!.selection;
        await tester.tap(find.byKey(const ValueKey('entryDetailDoneButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('entryDetailEditButton')));
        await tester.pumpAndSettle();
        field = tester.widget<TextField>(editor);
        expect(field.controller!.text, cleaned ?? 'raw text');
        expect(field.controller!.selection, selection);
        expect(field.focusNode!.hasFocus, isTrue);
        await tester.enterText(editor, 'changed text');
        await tester.tap(find.byKey(const ValueKey('entryDetailDoneButton')));
        await tester.pumpAndSettle();
        await tester.tap(body);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(editor).controller!.text,
          'changed text',
        );
        await tester.tap(editor);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('entryDetailDoneButton')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('scrolling and metadata taps remain in reading mode', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(
        id: 1,
        rawTranscript: 'raw',
        cleanedText: List.filled(80, 'Long entry line').join('\n'),
      ),
    ]);
    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );
    for (final key in [
      'entryDetailWeekday',
      'entryDetailDate',
      'entryDetailWordCount',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
    }
    await tester.drag(
      find.byKey(const ValueKey('entryDetailScrollView')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailEditor')), findsNothing);
  });

  testWidgets('body semantic action exposes text and starts editing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw', cleanedText: 'accessible text'),
    ]);
    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );
    final action = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.hint == 'Tap to edit entry',
    );
    expect(action, findsOneWidget);
    final node = tester.getSemantics(action);
    expect(node.getSemanticsData().value, 'accessible text');
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('entryDetailEditor')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('loading has no body edit action', (tester) async {
    entryRepository.holdEntryLoading = true;
    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
      settle: false,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('entryDetailLoading')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  for (final action in ['entryDetailDoneButton', 'entryDetailBackButton']) {
    testWidgets('failed save after body tap keeps editing on $action', (
      tester,
    ) async {
      entryRepository.throwOnEdit = true;
      entryRepository.seedEntries([
        _entry(id: 1, rawTranscript: 'raw', cleanedText: 'original'),
      ]);
      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
      );
      await tester.tap(find.byKey(const ValueKey('entryDetailReadText')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('entryDetailEditor')),
        'changed',
      );
      await tester.tap(find.byKey(ValueKey(action)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entryDetailEditor')), findsOneWidget);
      expect(find.text('Could not save your changes.'), findsWidgets);
      expect((await entryRepository.getEntryById(1))!.cleanedText, 'original');
    });
  }

  testWidgets('renders cleaned text, metadata, and word count', (tester) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('clean text'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailWeekday')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailDate')), findsOneWidget);
    expect(find.text('2 words'), findsOneWidget);
  });

  testWidgets('falls back to raw transcript when cleaned text is unavailable', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw fallback text', cleanedText: null),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    expect(find.text('raw fallback text'), findsOneWidget);
  });

  testWidgets('missing entries redirect back to the entry list', (
    tester,
  ) async {
    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
      initialLocation: '/entry/99',
    );

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });

  testWidgets('unreadable entries redirect back to the entry list', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(
        id: 1,
        rawTranscript: '',
        cleanedText: null,
        type: EntryType.draft,
        audioPath: '/tmp/audio.m4a',
        wordCount: 0,
      ),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('auto-saves edits and flushes them before navigating back', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
      autoSaveDelay: Duration.zero,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailEditButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entryDetailEditor')),
      'edited detail text',
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('entryDetailBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    final updatedEntry = await entryRepository.getEntryById(1);
    expect(updatedEntry, isNotNull);
    expect(updatedEntry!.cleanedText, 'edited detail text');
    expect(updatedEntry.rawTranscript, 'raw text');
    expect(updatedEntry.wordCount, 3);
  });

  testWidgets('share failure shows a generic message', (tester) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);
    shareService.throwOnShare = true;

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
    await tester.pumpAndSettle();

    expect(find.text('Could not share this entry.'), findsOneWidget);
  });

  testWidgets('share includes the entry timestamp and displayed body text', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailShareButton')));
    await tester.pumpAndSettle();

    expect(shareService.sharedTexts, [_expectedShareText('clean text')]);
  });

  testWidgets('system back flushes edits and returns to the entry list', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
      autoSaveDelay: Duration.zero,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailEditButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entryDetailEditor')),
      'edited via system back',
    );
    await tester.pump();
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    final updatedEntry = await entryRepository.getEntryById(1);
    expect(updatedEntry, isNotNull);
    expect(updatedEntry!.cleanedText, 'edited via system back');
  });

  testWidgets('delete cancel keeps the user on detail', (tester) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(await entryRepository.getEntryById(1), isNotNull);
  });

  testWidgets('delete confirm removes the entry and returns to entries', (
    tester,
  ) async {
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
    expect(await entryRepository.getEntryById(1), isNull);
  });

  testWidgets('delete failure keeps the user on detail', (tester) async {
    entryRepository
      ..throwOnDelete = true
      ..seedEntries([
        _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
      ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    await tester.tap(find.byKey(const ValueKey('entryDetailDeleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(await entryRepository.getEntryById(1), isNotNull);
  });

  testWidgets('exposes meaningful semantics labels for detail actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.seedEntries([
      _entry(id: 1, rawTranscript: 'raw text', cleanedText: 'clean text'),
    ]);

    await _pumpEntryDetailApp(
      tester,
      entryRepository: entryRepository,
      shareService: shareService,
    );

    expect(find.bySemanticsLabel('Back to entries'), findsOneWidget);
    expect(find.bySemanticsLabel('Edit entry'), findsOneWidget);
    expect(find.bySemanticsLabel('Share entry'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete entry'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryDetailEditButton')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Edit entry text'), findsOneWidget);

    semanticsHandle.dispose();
  });

  group('raw transcript debug section', () {
    const rawTranscriptKey = ValueKey('entryDetailRawTranscript');

    testWidgets('shows raw transcript when debug mode enabled', (tester) async {
      entryRepository.seedEntries([
        _entry(
          id: 1,
          rawTranscript: 'raw version',
          cleanedText: 'cleaned version',
        ),
      ]);

      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
        debugDeviceMode: true,
      );

      expect(find.byKey(rawTranscriptKey), findsOneWidget);
      expect(find.text('raw version'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('entryDetailRawTranscriptLabel')),
        findsOneWidget,
      );
    });

    testWidgets('hides raw transcript when debug mode disabled', (
      tester,
    ) async {
      entryRepository.seedEntries([
        _entry(
          id: 1,
          rawTranscript: 'raw version',
          cleanedText: 'cleaned version',
        ),
      ]);

      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
      );

      expect(find.byKey(rawTranscriptKey), findsNothing);
    });

    testWidgets('hides raw transcript when texts are identical', (
      tester,
    ) async {
      entryRepository.seedEntries([
        _entry(id: 1, rawTranscript: 'same text', cleanedText: 'same text'),
      ]);

      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
        debugDeviceMode: true,
      );

      expect(find.byKey(rawTranscriptKey), findsNothing);
    });

    testWidgets('hides raw transcript when cleanedText is null',
        (tester) async {
      entryRepository.seedEntries([
        _entry(
          id: 1,
          rawTranscript: 'raw only entry',
          cleanedText: null,
        ),
      ]);

      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
        debugDeviceMode: true,
      );

      expect(find.byKey(rawTranscriptKey), findsNothing);
    });

    testWidgets('hides raw transcript for draft entries', (tester) async {
      entryRepository.seedEntries([
        _entry(
          id: 1,
          rawTranscript: 'raw',
          cleanedText: 'cleaned',
          type: EntryType.draft,
        ),
      ]);

      await _pumpEntryDetailApp(
        tester,
        entryRepository: entryRepository,
        shareService: shareService,
        debugDeviceMode: true,
      );

      expect(find.byKey(rawTranscriptKey), findsNothing);
    });
  });
}

Future<void> _pumpEntryDetailApp(
  WidgetTester tester, {
  required _TestEntryRepository entryRepository,
  required _TestEntryShareService shareService,
  String initialLocation = '/entry/1',
  Duration autoSaveDelay = const Duration(milliseconds: 1),
  bool settle = true,
  bool debugDeviceMode = false,
}) async {
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(
          buildAppRouter(initialLocation: initialLocation),
        ),
        appLockEnabledProvider.overrideWithValue(false),
        debugDeviceModeProvider.overrideWith((ref) async => debugDeviceMode),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        preferencesRepositoryProvider.overrideWithValue(
          const _TestPreferencesRepository(),
        ),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        entryShareServiceProvider.overrideWithValue(shareService),
        entryDetailAutoSaveDelayProvider.overrideWithValue(autoSaveDelay),
        mainRecordingControllerProvider.overrideWith(
          _TestMainRecordingController.new,
        ),
        sessionRecordQuotaStateProvider.overrideWith(_TestQuotaNotifier.new),
      ],
      child: const WraitApp(),
    ),
  );

  if (settle) await tester.pumpAndSettle();
}

class _TestMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _entriesController =
      StreamController<List<Entry>>.broadcast();
  final Map<int, Entry> _entriesById = <int, Entry>{};
  bool throwOnEdit = false;
  bool holdEntryLoading = false;
  bool throwOnDelete = false;

  void seedEntries(List<Entry> entries) {
    _entriesById
      ..clear()
      ..addEntries(entries.map((entry) => MapEntry(entry.id, entry)));
    _emitEntries();
  }

  Future<void> dispose() => _entriesController.close();

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    yield _sortedEntries;
    yield* _entriesController.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) async* {
    if (holdEntryLoading) {
      yield* const Stream<Entry?>.empty();
      return;
    }
    yield _entriesById[id];
    yield* _entriesController.stream.map((_) => _entriesById[id]);
  }

  @override
  Future<Entry?> getEntryById(int id) async => _entriesById[id];

  @override
  Future<List<int>> importEntries(List<Entry> entries) async => const [];

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {
    if (throwOnEdit) {
      throw StateError('edit failed');
    }

    final entry = _entriesById[id];
    if (entry == null) {
      throw StateError('entry missing');
    }

    _entriesById[id] = entry.copyWith(
      cleanedText: cleanedText,
      wordCount: _countWords(cleanedText),
    );
    _emitEntries();
  }

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {
    if (throwOnDelete) {
      throw StateError('delete failed');
    }

    _entriesById.remove(id);
    _emitEntries();
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  List<Entry> get _sortedEntries {
    final entries = _entriesById.values.toList(growable: false);
    entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return entries;
  }

  void _emitEntries() {
    _entriesController.add(_sortedEntries);
  }

  int _countWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
  }
}

class _TestEntryShareService implements EntryShareService {
  bool throwOnShare = false;
  final List<String> sharedTexts = <String>[];

  @override
  Future<void> shareText(String text) async {
    if (throwOnShare) {
      throw StateError('share failed');
    }
    sharedTexts.add(text);
  }
}

String _expectedShareText(String body) {
  final shareTimestamp = formatEntryDetailShareTimestamp(
    createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
    locale: const Locale('en', 'US'),
  );
  return '$shareTimestamp$entryDetailShareSectionSeparator$body';
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Entry _entry({
  required int id,
  required String rawTranscript,
  required String? cleanedText,
  EntryType type = EntryType.saved,
  String? audioPath,
  int wordCount = 2,
}) {
  return Entry(
    id: id,
    rawTranscript: rawTranscript,
    cleanedText: cleanedText,
    type: type,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 16, 9).millisecondsSinceEpoch,
    wordCount: wordCount,
    audioPath: audioPath,
  );
}
