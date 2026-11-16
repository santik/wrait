import '../../domain/service/entry_export_service.dart';
import '../../domain/service/entry_import_service.dart';
import '../../l10n/app_localizations.dart';

/// Maps an [EntryExportResult] to the localized snackbar message to show the
/// user. Pure (no widgets) so the mapping is unit-testable and reusable across
/// any screen that drives a backup export.
String exportResultMessage(AppLocalizations l10n, EntryExportResult result) {
  if (result.didExport) {
    return l10n.entryListExportSuccess(result.fileName!, result.pathLabel!);
  }
  return l10n.entryListExportFailed;
}

/// Maps a completed (non-cancelled) [EntryImportResult] to the localized
/// snackbar message. Callers must handle [EntryImportResult.wasCancelled]
/// (show nothing) before calling this.
String importResultMessage(AppLocalizations l10n, EntryImportResult result) {
  if (result.didImport) {
    return l10n.entryListImportSuccess(result.importedCount, result.fileName!);
  }
  return switch (result.failureCategory) {
    EntryImportFailureCategory.invalidFormat =>
      l10n.entryListImportInvalidFormat,
    EntryImportFailureCategory.unreadableFile =>
      l10n.entryListImportUnreadableFile,
    EntryImportFailureCategory.fileTooLarge =>
      l10n.entryListImportFileTooLarge,
    EntryImportFailureCategory.storageFailure =>
      l10n.entryListImportStorageFailure,
    null => l10n.entryListImportFailed,
  };
}
