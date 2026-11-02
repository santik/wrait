abstract interface class RemindersPreferencesRepository {
  Future<bool> getRemindersEnabled();
  Future<void> setRemindersEnabled(bool value);
}
