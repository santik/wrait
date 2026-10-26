import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/device_token_store.dart';
import 'package:wrait/data/entries/database_key_store.dart';

import '../../test_doubles/fake_secure_storage.dart';

void main() {
  group('DeviceTokenStore', () {
    test('uses the wrait_device_token key', () {
      expect(DeviceTokenStore.storageKey, 'wrait_device_token');
    });

    test('read returns null when nothing is stored', () async {
      final store = DeviceTokenStore(FakeSecureKeyValueStore());
      expect(await store.read(), isNull);
    });

    test('write then read round-trips and persists under the key', () async {
      final storage = FakeSecureKeyValueStore();
      final store = DeviceTokenStore(storage);

      await store.write('abc.def');

      expect(await store.read(), 'abc.def');
      expect(await storage.read('wrait_device_token'), 'abc.def');
    });

    test('clear removes the token', () async {
      final store = DeviceTokenStore(FakeSecureKeyValueStore());
      await store.write('abc.def');

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('empty value is treated as missing', () async {
      final store = DeviceTokenStore(
        FakeSecureKeyValueStore(<String, String>{'wrait_device_token': ''}),
      );
      expect(await store.read(), isNull);
    });

    test('unreadable storage is treated as missing, not a crash', () async {
      final store = DeviceTokenStore(_ThrowingStore());
      expect(await store.read(), isNull);
    });
  });
}

class _ThrowingStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => throw StateError('keystore');

  @override
  Future<void> write(String key, String value) async {}
}
