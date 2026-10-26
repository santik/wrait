import '../entries/database_key_store.dart';

/// Secure storage for the server-issued device token.
///
/// The token is a credential: it must never be logged, exported, or included
/// in feedback/crash payloads. This class intentionally exposes no
/// `toString`/debug output containing the value.
class DeviceTokenStore {
  DeviceTokenStore(this._storage);

  static const storageKey = 'wrait_device_token';

  final SecureKeyValueStore _storage;

  /// Returns the stored token, or null when absent, empty, or unreadable.
  Future<String?> read() async {
    try {
      final value = await _storage.read(storageKey);
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    } catch (_) {
      // Unreadable secure storage is treated as "no token"; the client
      // re-registers to obtain a fresh one.
      return null;
    }
  }

  Future<void> write(String token) => _storage.write(storageKey, token);

  Future<void> clear() => _storage.delete(storageKey);
}
