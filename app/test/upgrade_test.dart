import 'package:flutter_test/flutter_test.dart';
import 'package:childmbti/upgrade.dart';

void main() {
  test('버전 비교', () {
    expect(newer('1.2.10', '1.2.9'), isTrue);
    expect(newer('1.3.0', '1.2.0+6'), isTrue);
    expect(newer('1.2.0', '1.2.0'), isFalse);
    expect(newer('1.1.9', '1.2.0'), isFalse);
  });
}
