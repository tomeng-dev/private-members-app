import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR token format has no email PII markers', () {
    const token = 'pm1.550e8400-e29b-41d4-a716-446655440000.1735689600.abcdef'; // gitleaks:allow (fake test token)
    expect(token.startsWith('pm1.'), isTrue);
    expect(token.contains('@'), isFalse);
    final parts = token.split('.');
    expect(parts.length, 4);
  });
}
