import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entries/entry_providers.dart';
import '../../domain/repository/entry_repository.dart';

typedef EntryDeletionWarningLogger = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  int? entryId,
});

final entryDeletionWarningLoggerProvider = Provider<EntryDeletionWarningLogger>(
  (ref) {
    return (message, {error, stackTrace, entryId}) {
      developer.log(
        message,
        name: 'EntryDeletionController',
        error: error,
        stackTrace: stackTrace,
        sequenceNumber: entryId,
      );
    };
  },
);

final entryDeletionControllerProvider = Provider<EntryDeletionController>((
  ref,
) {
  return EntryDeletionController(
    entryRepository: ref.read(entryRepositoryProvider),
    logWarning: ref.read(entryDeletionWarningLoggerProvider),
  );
});

class EntryDeletionController {
  const EntryDeletionController({
    required this._entryRepository,
    required this._logWarning,
  });

  final EntryRepository _entryRepository;
  final EntryDeletionWarningLogger _logWarning;

  Future<bool> deleteEntry(int id, {required String failureContext}) async {
    try {
      await _entryRepository.deleteEntry(id);
      return true;
    } catch (error, stackTrace) {
      _logWarning(
        failureContext,
        error: error,
        stackTrace: stackTrace,
        entryId: id,
      );
      return false;
    }
  }
}
