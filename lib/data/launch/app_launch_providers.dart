import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecase/app_launch_work_use_case.dart';
import '../../domain/usecase/retry_pending_drafts_use_case.dart';
import '../api/backend_providers.dart';
import '../entries/entry_providers.dart';
import '../entries/tag_providers.dart';
import '../preferences/preferences_providers.dart';
import '../transcription/transcription_providers.dart';

final appLaunchWorkWarningLoggerProvider = Provider<AppLaunchWorkWarningLogger>(
  (ref) {
    return (message, {error, stackTrace}) {
      developer.log(
        message,
        name: 'AppLaunchWork',
        error: error,
        stackTrace: stackTrace,
      );
    };
  },
);

final retryPendingDraftsWarningLoggerProvider =
    Provider<RetryPendingDraftsWarningLogger>((ref) {
      return (message, {error, stackTrace}) {
        developer.log(
          message,
          name: 'RetryPendingDraftsUseCase',
          error: error,
          stackTrace: stackTrace,
        );
      };
    });

final validateDraftAudioPathProvider = Provider<ValidateDraftAudioPathCallback>(
  (ref) {
    return (path) async {
      final trimmedPath = path.trim();
      if (trimmedPath.isEmpty) {
        return null;
      }

      final file = File(trimmedPath);
      try {
        if (!await file.exists()) {
          return null;
        }

        final handle = await file.open(mode: FileMode.read);
        try {
          // Open the file to prove it is readable before retry uploads.
        } finally {
          await handle.close();
        }

        if (await file.length() <= 0) {
          return null;
        }
      } on FileSystemException {
        return null;
      }

      return trimmedPath;
    };
  },
);

final deleteRetainedAudioProvider = Provider<DeleteRetainedAudioCallback>((
  ref,
) {
  return (path) async {
    final trimmedPath = path.trim();
    if (trimmedPath.isEmpty) {
      return;
    }

    final file = File(trimmedPath);
    if (await file.exists()) {
      await file.delete();
    }
  };
});

final retryPendingDraftsUseCaseProvider = Provider<RetryPendingDraftsUseCase>((
  ref,
) {
  return RetryPendingDraftsUseCase(
    entryRepository: ref.watch(entryRepositoryProvider),
    transcriptionService: ref.watch(transcriptionServiceProvider),
    cleanupTranscriptUseCase: ref.watch(cleanupTranscriptUseCaseProvider),
    validateDraftAudioPath: ref.watch(validateDraftAudioPathProvider),
    deleteRetainedAudio: ref.watch(deleteRetainedAudioProvider),
    setRecordQuota: (quota) {
      ref.read(sessionRecordQuotaStateProvider.notifier).setQuota(quota);
    },
    logWarning: ref.watch(retryPendingDraftsWarningLoggerProvider),
    autoTagUseCase: ref.watch(autoTagUseCaseProvider),
    tagText: ({required String text, required List<String> tags}) {
      return ref
          .read(wraitBackendClientProvider)
          .tagText(text: text, tags: tags);
    },
    tagRepository: ref.watch(tagRepositoryProvider),
    autoTagEnabled: ref.watch(isDebugDeviceProvider),
  );
});

final appLaunchWorkUseCaseProvider = Provider<AppLaunchWorkUseCase>((ref) {
  return AppLaunchWorkUseCase(
    registerDeviceOnLaunch: ref.watch(registerDeviceOnLaunchUseCaseProvider),
    retryPendingDrafts: () =>
        ref.read(retryPendingDraftsUseCaseProvider).call(),
    logWarning: ref.watch(appLaunchWorkWarningLoggerProvider),
  );
});
