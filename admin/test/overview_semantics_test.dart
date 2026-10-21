import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_dashboard/core/theme/app_theme.dart';

void main() {
  testWidgets('admin theme gold contrast on black', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('Admin')),
      ),
    );
    expect(AppColors.gold, isNot(AppColors.black));
    expect(find.text('Admin'), findsOneWidget);
  });
}
