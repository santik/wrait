import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/supported_language.dart';
import 'preferences_providers.dart';

/// Thrown when the stored transcription language could not be loaded, so the
/// caller must not silently fall back to automatic language detection.
class TranscriptionLanguageUnavailableException implements Exception {
  const TranscriptionLanguageUnavailableException();

  @override
  String toString() => 'The saved transcription language could not be loaded.';
}

enum TranscriptionLanguageStatus { loading, ready, loadFailure }

class TranscriptionLanguageState {
  const TranscriptionLanguageState({
    required this.status,
    this.language,
    this.isSaving = false,
    this.saveFailed = false,
  });

  const TranscriptionLanguageState.loading()
    : this(status: TranscriptionLanguageStatus.loading);

  const TranscriptionLanguageState.loadFailure()
    : this(status: TranscriptionLanguageStatus.loadFailure);

  final TranscriptionLanguageStatus status;
  final String? language;
  final bool isSaving;
  final bool saveFailed;

  bool get isReady => status == TranscriptionLanguageStatus.ready;

  TranscriptionLanguageState copyWith({
    String? language,
    bool clearLanguage = false,
    bool? isSaving,
    bool? saveFailed,
  }) {
    return TranscriptionLanguageState(
      status: status,
      language: clearLanguage ? null : language ?? this.language,
      isSaving: isSaving ?? this.isSaving,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}

final transcriptionLanguageControllerProvider =
    NotifierProvider<
      TranscriptionLanguageController,
      TranscriptionLanguageState
    >(TranscriptionLanguageController.new);

class TranscriptionLanguageController
    extends Notifier<TranscriptionLanguageState> {
  Future<void>? _loadFuture;
  Future<bool>? _saveFuture;
  int _operationId = 0;

  @override
  TranscriptionLanguageState build() {
    _loadFuture = _load();
    return const TranscriptionLanguageState.loading();
  }

  Future<void> retryLoad() async {
    if (state.status == TranscriptionLanguageStatus.loading) {
      return _loadFuture ?? Future<void>.value();
    }
    state = const TranscriptionLanguageState.loading();
    _loadFuture = _load();
    await _loadFuture;
  }

  Future<bool> setLanguage(String? language) async {
    // Serialize saves: wait for any in-flight save to finish (re-checking,
    // since another waiter may start a new save first), then proceed. The
    // checks below and the _save call must stay synchronous after the loop so
    // only one waiter can start the next save.
    while (_saveFuture != null) {
      await _saveFuture;
    }
    if (!state.isReady || state.language == language) {
      return false;
    }
    if (language != null && !supportedLanguageCodes.contains(language)) {
      throw ArgumentError.value(language, 'language', 'unsupported language');
    }

    final future = _save(language);
    _saveFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_saveFuture, future)) {
        _saveFuture = null;
      }
    }
  }

  Future<String?> snapshotLanguage() async {
    final loadFuture = _loadFuture;
    if (loadFuture != null) {
      await loadFuture;
    }
    while (_saveFuture != null) {
      await _saveFuture;
    }
    if (state.status == TranscriptionLanguageStatus.loadFailure) {
      // One more attempt before giving up, so a transient storage error does
      // not silently downgrade the user's saved language to auto-detect.
      await retryLoad();
      final retrySave = _saveFuture;
      if (retrySave != null) {
        await retrySave;
      }
    }
    if (!state.isReady) {
      throw const TranscriptionLanguageUnavailableException();
    }
    return state.language;
  }

  Future<void> _load() async {
    final operationId = ++_operationId;
    try {
      final language = await ref
          .read(transcriptionLanguagePreferencesRepositoryProvider)
          .getTranscriptionLanguage();
      if (!ref.mounted || operationId != _operationId) {
        return;
      }
      state = TranscriptionLanguageState(
        status: TranscriptionLanguageStatus.ready,
        language: language,
      );
    } catch (_) {
      if (ref.mounted && operationId == _operationId) {
        state = const TranscriptionLanguageState.loadFailure();
      }
    }
  }

  Future<bool> _save(String? language) async {
    final operationId = ++_operationId;
    state = state.copyWith(isSaving: true, saveFailed: false);
    try {
      await ref
          .read(transcriptionLanguagePreferencesRepositoryProvider)
          .setTranscriptionLanguage(language);
    } catch (_) {
      if (ref.mounted && operationId == _operationId) {
        state = state.copyWith(isSaving: false, saveFailed: true);
      }
      return false;
    }

    if (!ref.mounted || operationId != _operationId) {
      return false;
    }
    state = state.copyWith(
      language: language,
      clearLanguage: language == null,
      isSaving: false,
      saveFailed: false,
    );
    return true;
  }
}
