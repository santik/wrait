abstract interface class ThemePreferencesRepository {
  Future<String?> getThemeMode();
  Future<void> setThemeMode(String value);
}
