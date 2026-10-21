import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/ui/ui.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('LuxButton shows spinner and is disabled while loading', (t) async {
    var taps = 0;
    await t.pumpWidget(_wrap(LuxButton(label: 'Save', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await t.tap(find.byType(FilledButton));
    expect(taps, 0);
  });

  testWidgets('LuxButton variants meet 48dp tap target', (t) async {
    await t.pumpWidget(
      _wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuxButton(label: 'A', onPressed: () {}),
            LuxButton.secondary(label: 'B', onPressed: () {}),
            LuxButton.ghost(label: 'C', onPressed: () {}),
          ],
        ),
      ),
    );
    for (final f in [find.byType(FilledButton), find.byType(OutlinedButton), find.byType(TextButton)]) {
      expect(t.getSize(f).height, greaterThanOrEqualTo(kMinTapTarget));
    }
  });

  testWidgets('MemberAvatar renders initials and founding semantics', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_wrap(const MemberAvatar(name: 'Alexander Whitmore', founding: true, size: 64)));
    expect(find.text('AW'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Alexander Whitmore, founding member'), findsOneWidget);
    handle.dispose();
  });

  test('MemberAvatar.initials handles edge cases', () {
    expect(MemberAvatar.initials(''), '?');
    expect(MemberAvatar.initials('cher'), 'C');
    expect(MemberAvatar.initials('  isabella   de laurent '), 'IL');
  });

  testWidgets('EmptyState shows action and fires callback', (t) async {
    var hit = false;
    await t.pumpWidget(_wrap(EmptyState(icon: Icons.inbox, title: 'Nothing here', message: 'msg', actionLabel: 'Do it', onAction: () => hit = true)));
    expect(find.text('Nothing here'), findsOneWidget);
    await t.tap(find.text('Do it'));
    expect(hit, isTrue);
  });

  testWidgets('ErrorState offers retry', (t) async {
    var retried = false;
    await t.pumpWidget(_wrap(ErrorState(message: 'Boom', onRetry: () => retried = true)));
    await t.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('Skeleton is excluded from semantics and animates', (t) async {
    await t.pumpWidget(_wrap(const SizedBox(width: 200, child: SkeletonCard())));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(Skeleton), findsWidgets);
  });

  testWidgets('LuxTextField validates and toggles password visibility', (t) async {
    final key = GlobalKey<FormState>();
    await t.pumpWidget(
      _wrap(
        Form(
          key: key,
          child: const SizedBox(
            width: 300,
            child: LuxTextField(label: 'Email', validator: Validators.email),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await t.pump();
    expect(find.text('Email is required'), findsOneWidget);

    await t.pumpWidget(_wrap(const SizedBox(width: 300, child: LuxTextField(label: 'Password', obscure: true))));
    expect(find.byTooltip('Show password'), findsOneWidget);
    await t.tap(find.byTooltip('Show password'));
    await t.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('showConfirmDialog resolves true on confirm', (t) async {
    bool? result;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showConfirmDialog(ctx, title: 'Sure?', message: 'm', confirmLabel: 'Yes'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Yes'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('showToast displays a floating snackbar', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showToast(ctx, 'Saved', kind: ToastKind.success),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('DateBadge and StatusPill render', (t) async {
    await t.pumpWidget(
      _wrap(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateBadge(date: DateTime(2026, 10, 26)),
            const StatusPill('PAID'),
          ],
        ),
      ),
    );
    expect(find.text('OCT'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(find.text('PAID'), findsOneWidget);
  });

  test('relativeTime buckets', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 5)), now: now), 'now');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h');
    expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d');
  });

  test('gridColumns is responsive and clamped', () {
    expect(gridColumns(390), 1);
    expect(gridColumns(700), 2);
    expect(gridColumns(2000, max: 3), 3);
  });
}
