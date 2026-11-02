import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../api/backend_providers.dart';
import '../audio/audio_recording_providers.dart';
import '../preferences/transcription_language_controller.dart';
import 'cloud_transcription_service.dart';
import 'transcription_service.dart';

final liveRecordingPathFactoryProvider = Provider<LiveRecordingPathFactory>((
  ref,
) {
  final random = Random();

  return () async {
    final tempDirectory = await getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final nonce = random.nextInt(1 << 32).toRadixString(16);
    return path.join(tempDirectory.path, 'wrait-live-$timestamp-$nonce.m4a');
  };
});

final transcriptionWarningLoggerProvider = Provider<TranscriptionWarningLogger>(
  (ref) {
    return (message, {error, stackTrace}) {
      developer.log(
        message,
        name: 'CloudTranscriptionService',
        error: error,
        stackTrace: stackTrace,
      );
    };
  },
);

final transcribeAudioCallbackProvider = Provider<TranscribeAudioCallback>((
  ref,
) {
  return ref.watch(wraitBackendClientProvider).transcribeAudio;
});

final transcriptionActivityProvider =
    NotifierProvider<TranscriptionActivityNotifier, bool>(
      TranscriptionActivityNotifier.new,
    );

class TranscriptionActivityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool value) {
    state = value;
  }
}

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  return CloudTranscriptionService(
    audioRecordingService: ref.watch(audioRecordingServiceProvider),
    transcribeAudio: ref.watch(transcribeAudioCallbackProvider),
    createLiveRecordingPath: ref.watch(liveRecordingPathFactoryProvider),
    readLanguageSnapshot: () => ref
        .read(transcriptionLanguageControllerProvider.notifier)
        .snapshotLanguage(),
    onActivityChanged: (isActive) {
      ref.read(transcriptionActivityProvider.notifier).setActive(isActive);
    },
    logWarning: ref.watch(transcriptionWarningLoggerProvider),
  );
});
