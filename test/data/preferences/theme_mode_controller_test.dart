import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/preferences/theme_mode_controller.dart';
import 'package:wrait/domain/repository/theme_preferences_repository.dart';

void main() {
  test('loads system default and publishes a successfully saved theme', () async {
    final repository = _ThemeRepository();
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(themeModeControllerProvider);
    expect(state.themeMode, ThemeMode.system);
    expect(state.isSaving, isFalse);
    expect(state.saveFailed, isFalse);

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    final afterSave = container.read(themeModeControllerProvider);
    expect(afterSave.themeMode, ThemeMode.dark);
    expect(afterSave.isSaving, isFalse);
    expect(afterSave.saveFailed, isFalse);
    expect(repository.storedValue, 'dark');
  });

  test('loads a persisted preference on start', () async {
    final repository = _ThemeRepository(storedValue: 'light');
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    // Trigger build, then let the async _load() complete.
    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(themeModeControllerProvider).themeMode,
        ThemeMode.light);
  });

  test('invalid stored value falls back to system', () async {
    final repository = _ThemeRepository(storedValue: 'neon');
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(themeModeControllerProvider).themeMode,
        ThemeMode.system);
  });

  test('failed save keeps the attempted theme and reports failure', () async {
    final repository = _ThemeRepository(storedValue: 'light', failSaves: true);
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeModeControllerProvider).themeMode,
        ThemeMode.light);

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    final state = container.read(themeModeControllerProvider);
    expect(state.themeMode, ThemeMode.dark);
    expect(state.saveFailed, isTrue);
    expect(repository.storedValue, 'light');
  });

  test('setThemeMode is a no-op when already saving', () async {
    final gate = Completer<void>();
    final repository = _ThemeRepository(saveGate: gate.future);
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final first = container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeControllerProvider).isSaving, isTrue);

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.light);

    gate.complete();
    await first;

    final state = container.read(themeModeControllerProvider);
    expect(state.themeMode, ThemeMode.dark);
    expect(repository.saveCalls, 1);
  });

  test('setThemeMode is a no-op when selecting the current mode', () async {
    final repository = _ThemeRepository(storedValue: 'dark');
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(themeModeControllerProvider).themeMode,
        ThemeMode.dark);

    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(repository.saveCalls, 0);
  });

  test('load failure keeps system default silently', () async {
    final repository = _ThemeRepository(failLoads: true);
    final container = ProviderContainer(
      overrides: [
        themePreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(themeModeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(themeModeControllerProvider);
    expect(state.themeMode, ThemeMode.system);
    expect(state.saveFailed, isFalse);
  });
}

class _ThemeRepository implements ThemePreferencesRepository {
  _ThemeRepository({
    this.storedValue,
    this.failSaves = false,
    this.failLoads = false,
    this.saveGate,
  });

  String? storedValue;
  final bool failSaves;
  final bool failLoads;
  final Future<void>? saveGate;
  int saveCalls = 0;

  @override
  Future<String?> getThemeMode() async {
    if (failLoads) {
      throw StateError('load failed');
    }
    return storedValue;
  }

  @override
  Future<void> setThemeMode(String value) async {
    await saveGate;
    saveCalls += 1;
    if (failSaves) {
      throw StateError('save failed');
    }
    storedValue = value;
  }
}
