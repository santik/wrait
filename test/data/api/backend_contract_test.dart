import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/supported_language.dart';

void main() {
  test('backend language enum contains every selectable app language', () {
    final contract = File('api/wrait-backend.yaml').readAsStringSync();
    final parameterStart = contract.indexOf('    TranscriptionLanguage:');
    final responsesStart = contract.indexOf('  responses:', parameterStart);
    expect(parameterStart, greaterThanOrEqualTo(0));
    expect(responsesStart, greaterThan(parameterStart));

    final parameterBlock = contract.substring(parameterStart, responsesStart);
    final contractCodes = RegExp(
      r'^          - (.+)$',
      multiLine: true,
    ).allMatches(parameterBlock).map((match) => match.group(1)).toSet();

    expect(
      supportedLanguageCodes.difference(contractCodes.cast<String>()),
      isEmpty,
    );
    expect(contractCodes, contains('multi'));
    expect(supportedLanguageCodes, isNot(contains('multi')));
  });
}
