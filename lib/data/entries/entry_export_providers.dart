import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/service/entry_export_service.dart';
import 'entry_export_file_writer.dart';
import 'entry_providers.dart';

typedef EntryExportNow = DateTime Function();

final entryExportNowProvider = Provider<EntryExportNow>((ref) {
  final clock = ref.watch(clockProvider);
  // Reuse the shared clock abstraction so export timestamps stay deterministic
  // in widget and integration tests.
  return () => DateTime.fromMillisecondsSinceEpoch(clock.now(), isUtc: true);
});

final entryExportFileWriterProvider = Provider<EntryExportFileWriter>((ref) {
  return const MethodChannelEntryExportFileWriter();
});

final entryExportServiceProvider = Provider<EntryExportService>((ref) {
  return EntryExportService(
    fileWriter: ref.watch(entryExportFileWriterProvider),
    now: ref.watch(entryExportNowProvider),
  );
});
