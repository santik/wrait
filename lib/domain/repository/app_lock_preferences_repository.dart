abstract interface class AppLockPreferencesRepository {
  Future<bool> getAppLockEnabled();
  Future<void> setAppLockEnabled(bool value);
}
