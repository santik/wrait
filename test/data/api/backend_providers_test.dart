import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/api/backend_providers.dart';

void main() {
  test('backend dio provider applies base URL, proxy header, and explicit timeouts', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            backendUrl: 'https://example.com/api',
            proxySecret: 'proxy-secret',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(backendDioProvider);

    expect(dio, isA<Dio>());
    expect(dio.options.baseUrl, 'https://example.com/api');
    expect(dio.options.headers['X-Proxy-Secret'], 'proxy-secret');
    expect(dio.options.connectTimeout, backendConnectTimeout);
    expect(dio.options.sendTimeout, backendSendTimeout);
    expect(dio.options.receiveTimeout, backendReceiveTimeout);
  });
}
