import 'package:wrait/data/entries/database_key_store.dart';

class FakeSecureKeyValueStore implements SecureKeyValueStore {
  FakeSecureKeyValueStore([Map<String, String>? initialValues])
    : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
