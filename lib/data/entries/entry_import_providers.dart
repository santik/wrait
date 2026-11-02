import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/service/entry_import_service.dart';
import 'entry_import_file_reader.dart';
import 'entry_providers.dart';
import 'tag_providers.dart';

final entryImportFileReaderProvider = Provider<EntryImportFileReader>((ref) {
  return const MethodChannelEntryImportFileReader();
});

final entryImportServiceProvider = Provider<EntryImportService>((ref) {
  return EntryImportService(
    fileReader: ref.watch(entryImportFileReaderProvider),
    entryRepository: ref.watch(entryRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
  );
});
