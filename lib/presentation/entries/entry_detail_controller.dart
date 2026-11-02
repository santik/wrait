import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_providers.dart';
import '../../domain/model/entry.dart';
import '../../domain/repository/entry_repository.dart';
import 'entry_deletion_controller.dart';
import 'entry_detail_formatters.dart';
import 'entry_share_service.dart';

typedef EntryDetailWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

final entryDetailWarningLoggerProvider = Provider<EntryDetailWarningLogger>((
  ref,
) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'EntryDetailController',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final entryDetailAutoSaveDelayProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 400);
});

final entryDetailEntryProvider = StreamProvider.autoDispose.family<Entry?, int>(
  (ref, entryId) {
    return ref.watch(entryRepositoryProvider).watchEntryById(entryId);
  },
);

final entryDetailControllerProvider = NotifierProvider.family
    .autoDispose<EntryDetailController, EntryDetailControllerState, int>(
      EntryDetailController.new,
    );

class EntryDetailControllerState {
  const EntryDetailControllerState({
    this.isEditing = false,
    this.draftText = '',
    this.isSaving = false,
    this.saveFailed = false,
  });

  final bool isEditing;
  final String draftText;
  final bool isSaving;
  final bool saveFailed;

  EntryDetailControllerState copyWith({
    bool? isEditing,
    String? draftText,
    bool? isSaving,
    bool? saveFailed,
  }) {
    return EntryDetailControllerState(
      isEditing: isEditing ?? this.isEditing,
      draftText: draftText ?? this.draftText,
      isSaving: isSaving ?? this.isSaving,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}

class EntryDetailController extends Notifier<EntryDetailControllerState> {
  EntryDetailController(this._entryId);

  final int _entryId;

  Timer? _autoSaveTimer;
  Completer<bool>? _activeSaveCompleter;
  int _latestRequestedRevision = 0;
  int _lastPersistedRevision = 0;
  String? _latestRequestedText;
  String? _latestPersistedText;

  @override
  EntryDetailControllerState build() {
    ref.onDispose(() {
      _autoSaveTimer?.cancel();
    });
    return const EntryDetailControllerState();
  }

  EntryRepository get _entryRepository => ref.read(entryRepositoryProvider);
  EntryShareService get _entryShareService =>
      ref.read(entryShareServiceProvider);
  EntryDeletionController get _entryDeletionController =>
      ref.read(entryDeletionControllerProvider);
  EntryDetailWarningLogger get _logWarning =>
      ref.read(entryDetailWarningLoggerProvider);
  Duration get _autoSaveDelay => ref.read(entryDetailAutoSaveDelayProvider);

  void syncFromEntry(String displayText) {
    _latestPersistedText ??= displayText;
    _latestRequestedText ??= displayText;

    if (!state.isEditing && !state.isSaving) {
      _latestPersistedText = displayText;
      _latestRequestedText = displayText;
      _latestRequestedRevision = _lastPersistedRevision;
      state = state.copyWith(draftText: displayText, saveFailed: false);
    }
  }

  void startEditing(String initialText) {
    _latestPersistedText ??= initialText;
    _latestRequestedText ??= initialText;
    state = state.copyWith(
      isEditing: true,
      draftText: state.draftText.isEmpty ? initialText : state.draftText,
      saveFailed: false,
    );
  }

  Future<bool> finishEditing() async {
    final didFlush = await flushPendingEdits();
    if (!didFlush) {
      return false;
    }

    state = state.copyWith(isEditing: false, saveFailed: false);
    return true;
  }

  void updateDraftText(String text) {
    state = state.copyWith(draftText: text, saveFailed: false);
    _latestRequestedRevision += 1;
    _latestRequestedText = text;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      unawaited(flushPendingEdits());
    });
  }

  Future<bool> flushPendingEdits() async {
    _autoSaveTimer?.cancel();
    return _ensureRevisionSaved(_latestRequestedRevision);
  }

  Future<bool> shareDisplayedText({
    required String text,
    required String shareTimestamp,
  }) async {
    final shareText = '$shareTimestamp$entryDetailShareSectionSeparator$text';
    try {
      await _entryShareService.shareText(shareText);
      return true;
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to share the entry detail text.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteEntry() {
    return _entryDeletionController.deleteEntry(
      _entryId,
      failureContext: 'Failed to delete entry from the entry detail screen.',
    );
  }

  Future<bool> _ensureRevisionSaved(int targetRevision) async {
    while (_lastPersistedRevision < targetRevision) {
      if (_markRevisionSavedWithoutWrite(targetRevision)) {
        return true;
      }

      final activeSaveCompleter = _activeSaveCompleter;
      if (activeSaveCompleter != null) {
        final didSave = await activeSaveCompleter.future;
        if (!didSave && _lastPersistedRevision < targetRevision) {
          return _markRevisionSavedWithoutWrite(targetRevision);
        }
        continue;
      }

      await _saveLatestRequestedRevision();
      if (!ref.mounted) {
        return false;
      }
      if (state.saveFailed && _lastPersistedRevision < targetRevision) {
        return _markRevisionSavedWithoutWrite(targetRevision);
      }
    }

    return !state.saveFailed;
  }

  bool _markRevisionSavedWithoutWrite(int targetRevision) {
    final latestRequestedText = _latestRequestedText;
    if (latestRequestedText == null ||
        latestRequestedText != _latestPersistedText) {
      return false;
    }

    if (_lastPersistedRevision < targetRevision) {
      _lastPersistedRevision = targetRevision;
    }
    if (state.saveFailed) {
      state = state.copyWith(saveFailed: false);
    }
    return true;
  }

  Future<void> _saveLatestRequestedRevision() async {
    final revisionToPersist = _latestRequestedRevision;
    final textToPersist = _latestRequestedText;
    if (textToPersist == null || revisionToPersist <= _lastPersistedRevision) {
      return;
    }

    final completer = Completer<bool>();
    _activeSaveCompleter = completer;
    var didSave = false;
    state = state.copyWith(isSaving: true, saveFailed: false);

    try {
      await _entryRepository.updateEditedCleanedText(_entryId, textToPersist);
      if (!ref.mounted) {
        return;
      }
      _latestPersistedText = textToPersist;
      _lastPersistedRevision = revisionToPersist;
      didSave = true;
      state = state.copyWith(isSaving: false, saveFailed: false);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      _logWarning(
        'Failed to auto-save entry detail edits.',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isSaving: false, saveFailed: true);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
      if (!completer.isCompleted) {
        completer.complete(didSave);
      }
      if (identical(_activeSaveCompleter, completer)) {
        _activeSaveCompleter = null;
      }
    }
  }
}
