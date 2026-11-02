import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class DatabaseKeyStore {
  DatabaseKeyStore(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  static const storageKey = 'local_entry_database_key';

  final SecureKeyValueStore _storage;
  final Random _random;

  Future<String> readOrCreateKey() async {
    final existing = await _storage.read(storageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateKey();
    await _storage.write(storageKey, generated);
    return generated;
  }

  Future<void> deleteKey() => _storage.delete(storageKey);

  String _generateKey() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
