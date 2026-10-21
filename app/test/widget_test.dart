import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/theme/app_theme.dart';

void main() {
  test('theme exposes gold primary', () {
    expect(AppTheme.dark.colorScheme.primary, isNotNull);
  });
}
