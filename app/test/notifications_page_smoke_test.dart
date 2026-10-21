import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/theme/app_theme.dart';

void main() {
  testWidgets('theme exposes large tap targets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ElevatedButton(onPressed: () {}, child: const Text('Go')),
        ),
      ),
    );
    final size = tester.getSize(find.byType(ElevatedButton));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
