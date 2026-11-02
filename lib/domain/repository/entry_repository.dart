import '../model/entry.dart';

abstract interface class EntryRepository {
  Stream<List<Entry>> watchAllEntries();
  Stream<Entry?> watchEntryById(int id);
  Future<Entry?> getEntryById(int id);
  Future<List<int>> importEntries(List<Entry> entries);
  Future<int> saveDraft(String transcript, String language);
  Future<int> saveEntry(String transcript, String language);
  Future<int> saveAudioDraft(String audioPath, String language);
  Future<void> updateEditedCleanedText(int id, String cleanedText);
  Future<void> updateWithCleanedText(int id, String cleanedText, int wordCount);
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  );
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  );
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  );
  Future<void> updateEntryLanguage(int id, String language);
  Future<List<Entry>> getPendingDrafts();
  Future<void> deleteEntry(int id);
  Future<void> deleteStaleDrafts({int daysOld = 7});
}
