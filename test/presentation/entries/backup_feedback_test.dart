import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/service/entry_export_service.dart';
import 'package:wrait/domain/service/entry_import_service.dart';
import 'package:wrait/presentation/entries/backup_feedback.dart';

import '../../test_doubles/l10n_test_helper.dart';

void main() {
  final l10n = testL10n();

  group('exportResultMessage', () {
    test('success names the file and destination', () {
      final message = exportResultMessage(
        l10n,
        const EntryExportResult.success(
          fileName: 'entries.csv',
          pathLabel: 'Downloads/Wrait',
        ),
      );
      expect(message, 'Exported entries.csv to Downloads/Wrait.');
    });

    test('failure uses the generic export-failed message', () {
      final message = exportResultMessage(
        l10n,
        const EntryExportResult.failure(),
      );
      expect(message, 'Could not export entries.');
    });
  });

  group('importResultMessage', () {
    test('success names the count and file', () {
      final message = importResultMessage(
        l10n,
        const EntryImportResult.success(fileName: 'in.csv', importedCount: 2),
      );
      expect(message, 'Imported 2 records from in.csv.');
    });

    test('maps each failure category to its specific message', () {
      String forCategory(EntryImportFailureCategory category) =>
          importResultMessage(
            l10n,
            EntryImportResult.failure(failureCategory: category),
          );

      expect(
        forCategory(EntryImportFailureCategory.invalidFormat),
        'Selected CSV is not a valid Wrait export.',
      );
      expect(
        forCategory(EntryImportFailureCategory.unreadableFile),
        'Could not read the selected CSV file.',
      );
      expect(
        forCategory(EntryImportFailureCategory.fileTooLarge),
        'Selected CSV is too large to import.',
      );
      expect(
        forCategory(EntryImportFailureCategory.storageFailure),
        'Could not save imported entries.',
      );
    });

    test('null failure category falls back to the generic message', () {
      final message = importResultMessage(
        l10n,
        const EntryImportResult.failure(failureCategory: null),
      );
      expect(message, 'Could not import entries.');
    });
  });
}
