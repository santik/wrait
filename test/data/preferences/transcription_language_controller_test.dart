import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/preferences/transcription_language_controller.dart';
import 'package:wrait/domain/repository/transcription_language_preferences_repository.dart';

void main() {
  test(
    'loads automatic and publishes only a successfully saved language',
    () async {
      final repository = _LanguageRepository();
      final container = ProviderContainer(
        overrides: [
          transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        transcriptionLanguageControllerProvider.notifier,
      );
      expect(await controller.snapshotLanguage(), isNull);

      expect(await controller.setLanguage('nl-BE'), isTrue);
      expect(await controller.snapshotLanguage(), 'nl-BE');
      expect(repository.language, 'nl-BE');
    },
  );

  test(
    'failed save keeps the committed language and reports failure',
    () async {
      final repository = _LanguageRepository(language: 'en', failSaves: true);
      final container = ProviderContainer(
        overrides: [
          transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        transcriptionLanguageControllerProvider.notifier,
      );
      expect(await controller.snapshotLanguage(), 'en');

      expect(await controller.setLanguage('uk'), isFalse);
      expect(await controller.snapshotLanguage(), 'en');
      expect(
        container.read(transcriptionLanguageControllerProvider).saveFailed,
        isTrue,
      );
    },
  );

  test(
    'overlapping setLanguage calls do not deadlock and apply in order',
    () async {
      final gate = Completer<void>();
      final repository = _LanguageRepository(saveGate: gate.future);
      final container = ProviderContainer(
        overrides: [
          transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        transcriptionLanguageControllerProvider.notifier,
      );
      expect(await controller.snapshotLanguage(), isNull);

      final first = controller.setLanguage('nl-BE');
      final second = controller.setLanguage('uk');
      final third = controller.setLanguage('en');
      final snapshot = controller.snapshotLanguage();

      gate.complete();

      expect(await first.timeout(const Duration(seconds: 2)), isTrue);
      expect(await second.timeout(const Duration(seconds: 2)), isTrue);
      expect(await third.timeout(const Duration(seconds: 2)), isTrue);
      expect(await snapshot.timeout(const Duration(seconds: 2)), 'en');
      expect(repository.savedLanguages, ['nl-BE', 'uk', 'en']);
      expect(
        await controller.snapshotLanguage().timeout(const Duration(seconds: 2)),
        'en',
      );
    },
  );

  test(
    'snapshot retries a failed load and returns the stored language',
    () async {
      final repository = _LanguageRepository(language: 'uk', failLoads: 1);
      final container = ProviderContainer(
        overrides: [
          transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        transcriptionLanguageControllerProvider.notifier,
      );

      expect(await controller.snapshotLanguage(), 'uk');
      expect(repository.loadCalls, 2);
    },
  );

  test('snapshot throws instead of falling back to automatic when load keeps '
      'failing', () async {
    final repository = _LanguageRepository(language: 'uk', failLoads: 2);
    final container = ProviderContainer(
      overrides: [
        transcriptionLanguagePreferencesRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      transcriptionLanguageControllerProvider.notifier,
    );

    await expectLater(
      controller.snapshotLanguage(),
      throwsA(isA<TranscriptionLanguageUnavailableException>()),
    );
    expect(
      container.read(transcriptionLanguageControllerProvider).status,
      TranscriptionLanguageStatus.loadFailure,
    );
  });
}

class _LanguageRepository
    implements TranscriptionLanguagePreferencesRepository {
  _LanguageRepository({
    this.language,
    this.failSaves = false,
    this.saveGate,
    this.failLoads = 0,
  });

  String? language;
  final bool failSaves;
  int failLoads;
  int loadCalls = 0;
  final Future<void>? saveGate;
  final List<String?> savedLanguages = [];

  @override
  Future<String?> getTranscriptionLanguage() async {
    loadCalls += 1;
    if (failLoads > 0) {
      failLoads -= 1;
      throw StateError('load failed');
    }
    return language;
  }

  @override
  Future<void> setTranscriptionLanguage(String? language) async {
    await saveGate;
    if (failSaves) {
      throw StateError('save failed');
    }
    this.language = language;
    savedLanguages.add(language);
  }
}
