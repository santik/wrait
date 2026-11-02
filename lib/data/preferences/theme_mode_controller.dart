import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_providers.dart';

class ThemeModeState {
  const ThemeModeState({
    required this.themeMode,
    this.isSaving = false,
    this.saveFailed = false,
  });

  final ThemeMode themeMode;
  final bool isSaving;
  final bool saveFailed;
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeModeState>(
      ThemeModeController.new,
    );

class ThemeModeController extends Notifier<ThemeModeState> {
  int _operationId = 0;

  @override
  ThemeModeState build() {
    ref.onDispose(() {
      _operationId += 1;
    });
    unawaited(_load());
    return const ThemeModeState(themeMode: ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state.isSaving || state.themeMode == mode) {
      return;
    }

    final operationId = ++_operationId;
    state = ThemeModeState(themeMode: mode, isSaving: true);

    try {
      await ref
          .read(themePreferencesRepositoryProvider)
          .setThemeMode(_toStoredValue(mode));
    } catch (_) {
      if (ref.mounted && operationId == _operationId) {
        state = ThemeModeState(
          themeMode: state.themeMode,
          saveFailed: true,
        );
      }
      return;
    }

    if (!ref.mounted || operationId != _operationId) {
      return;
    }
    state = ThemeModeState(themeMode: mode);
  }

  Future<void> _load() async {
    final operationId = ++_operationId;
    try {
      final stored = await ref
          .read(themePreferencesRepositoryProvider)
          .getThemeMode();
      if (!ref.mounted || operationId != _operationId) {
        return;
      }
      state = ThemeModeState(themeMode: _fromStoredValue(stored));
    } catch (_) {
      // Keep system default on load failure.
    }
  }

  static ThemeMode _fromStoredValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _toStoredValue(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
