import 'package:flutter_test/flutter_test.dart';
import 'package:admin_dashboard/core/theme/app_theme.dart';

void main() {
  test('admin theme loads', () {
    expect(AppTheme.dark.colorScheme.primary, isNotNull);
  });
}
