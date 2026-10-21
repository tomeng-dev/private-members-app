import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/theme/app_theme.dart';
import 'package:member_app/features/auth/presentation/pages/welcome_page.dart';

void main() {
  testWidgets('welcome exposes Apply and Sign in (store happy-path entry)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const WelcomePage()),
      ),
    );
    expect(find.textContaining('Apply'), findsWidgets);
    expect(find.textContaining('Sign'), findsWidgets);
  });
}
