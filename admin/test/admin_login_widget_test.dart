import 'package:admin_dashboard/core/theme/app_theme.dart';
import 'package:admin_dashboard/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin login shows title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AdminLoginPage())));
    // Apply theme separately
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const AdminLoginPage()),
      ),
    );
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
