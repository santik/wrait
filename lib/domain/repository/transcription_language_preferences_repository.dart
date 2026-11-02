abstract interface class TranscriptionLanguagePreferencesRepository {
  Future<String?> getTranscriptionLanguage();

  Future<void> setTranscriptionLanguage(String? language);
}
