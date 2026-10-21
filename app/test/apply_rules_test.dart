import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/ui/lux_text_field.dart';
import 'package:member_app/features/applications/presentation/pages/apply_page.dart';

void main() {
  test('vehicle value must be >= 200k', () {
    expect(ApplyRules.value('199999'), isNotNull);
    expect(ApplyRules.value('250,000'), isNull);
    expect(ApplyRules.value(''), isNotNull);
  });
  test('year must be realistic', () {
    expect(ApplyRules.year('1850'), isNotNull);
    expect(ApplyRules.year('2024'), isNull);
    expect(ApplyRules.year('${DateTime.now().year + 5}'), isNotNull);
  });
  test('email validator', () {
    expect(Validators.email('a@b.co'), isNull);
    expect(Validators.email('nope'), isNotNull);
  });
}
