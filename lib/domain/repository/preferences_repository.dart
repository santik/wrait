abstract interface class PreferencesRepository {
  Future<bool> getHasEverRecorded();
  Future<void> setHasEverRecorded(bool value);
  Future<String> getDeviceId();
}
