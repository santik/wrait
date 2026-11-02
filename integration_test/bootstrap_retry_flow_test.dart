import 'package:integration_test/integration_test.dart';

import '../test/bootstrap_app_test.dart' as bootstrap_contract;

// Exercise the same injected bootstrap contract on the native Flutter host.
// Reuse its loading, failure, recovery and single-flight retry assertions.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  bootstrap_contract.main();
}
