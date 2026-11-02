import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audit for the spec requirement "no credential value ever written to logs":
/// the files that touch the device token must not contain any logging call.
void main() {
  const tokenHandlingFiles = <String>[
    'lib/data/api/device_token_store.dart',
    'lib/data/api/backend_client.dart',
    'lib/data/api/auth_interceptor.dart',
    'lib/data/api/generated/backend_api_generated.dart',
  ];
  final loggingPattern = RegExp(
    r'developer\.log|debugPrint|\bprint\(|logWarning|log\(|Logger|recordError|Wiredash',
  );

  for (final path in tokenHandlingFiles) {
    test('$path contains no logging or diagnostics calls', () {
      final source = File(path).readAsStringSync();
      expect(loggingPattern.hasMatch(source), isFalse);
    });
  }

  test('token is never passed to any logger or diagnostics sink', () {
    // backend_providers.dart legitimately wires loggers, so we cannot ban all
    // logging there; instead assert the token is never an argument to any
    // logging/diagnostics/crash-reporting sink. The sink list mirrors
    // [loggingPattern] above, and because `[^;]` spans newlines the match also
    // covers multi-line calls and string concatenation (e.g. `'tok: ' + token`
    // or `'$deviceToken'`) — any 'token' appearing anywhere inside the call.
    final providers = File('lib/data/api/backend_providers.dart')
        .readAsStringSync();
    final tokenToSink = RegExp(
      r'(developer\.log|debugPrint|\bprint\(|logWarning|\blog\(|Logger|'
      r'recordError|Wiredash|captureException|setCustomKey|analytics)'
      r'[^;]*[Tt]oken',
    );
    expect(tokenToSink.hasMatch(providers), isFalse);
  });
}
