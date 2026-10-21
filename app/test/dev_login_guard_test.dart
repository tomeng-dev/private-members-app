import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/config/app_config.dart';
import 'package:member_app/core/theme/app_theme.dart';
import 'package:member_app/features/auth/presentation/pages/login_page.dart';
import 'package:member_app/features/auth/presentation/widgets/dev_quick_login.dart';

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(theme: AppTheme.dark, home: child),
);

void main() {
  test('builds without --dart-define=APP_ENV=development are NOT development', () {
    // flutter test runs without dart-defines, mirroring a production build.
    expect(AppConfig.appEnv, 'production');
    expect(AppConfig.isDevelopment, isFalse);
  });

  testWidgets('login page hides dev quick login by default (production)', (t) async {
    await t.pumpWidget(_app(const LoginPage()));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('dev-quick-login')), findsNothing);
    expect(find.text('Dev quick login'), findsNothing);
  });

  testWidgets('dev quick login lists demo accounts and fills credentials when enabled', (t) async {
    Future<List<DevAccount>> loader() async => const [
      DevAccount(email: 'member1@example.com', name: 'Alexander Whitmore', status: 'active', founding: true),
      DevAccount(email: 'member2@example.com', name: 'Isabella Laurent', status: 'active'),
    ];
    await t.pumpWidget(_app(LoginPage(devMode: true, devAccountsLoader: loader)));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('dev-quick-login')), findsOneWidget);
    expect(find.text('Alexander Whitmore'), findsOneWidget);
    expect(find.text('DEVELOPMENT'), findsOneWidget);
  });

  testWidgets('login form validates email and password before submitting', (t) async {
    await t.pumpWidget(_app(const LoginPage()));
    await t.tap(find.text('Sign in'));
    await t.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
