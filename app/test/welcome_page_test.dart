import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/theme/app_theme.dart';
import 'package:member_app/features/auth/presentation/pages/welcome_page.dart';

void main() {
  testWidgets('Welcome page shows apply and sign in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const WelcomePage()),
      ),
    );
    expect(find.textContaining('PRIVATE MEMBERS'), findsOneWidget);
    expect(find.text('Apply for membership'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
