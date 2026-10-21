import 'package:admin_dashboard/core/ui/ui.dart';
import 'package:admin_dashboard/features/admin/presentation/shell.dart';
import 'package:admin_dashboard/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  home: Scaffold(body: child),
);

List<Map<String, dynamic>> _rows(int n) => [
  for (var i = 0; i < n; i++) {'id': 'id$i', 'name': 'Member $i', 'status': i.isEven ? 'active' : 'suspended'},
];

List<TableColumn<Map<String, dynamic>>> _cols() => [
  TableColumn(id: 'name', label: 'Name', sortKey: 'lastName', hideable: false, cell: (_, r) => Text('${r['name']}')),
  TableColumn(id: 'status', label: 'Status', width: 140, cell: (_, r) => StatusChip('${r['status']}')),
];

void main() {
  testWidgets('AdminDataTable renders rows, sorts, selects and paginates', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final q = TableQueryState(pageSize: 10);
    var changes = 0;
    Set<String> selected = {};
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _wrap(
          AdminDataTable<Map<String, dynamic>>(
            columns: _cols(),
            rows: _rows(3),
            idOf: (r) => '${r['id']}',
            rowLabel: (r) => '${r['name']}',
            query: q,
            total: 25,
            onQueryChanged: () => changes++,
            selected: selected,
            onSelectionChanged: (s) => setState(() => selected = s),
          ),
        ),
      ),
    );
    expect(find.text('Member 0'), findsOneWidget);
    expect(find.text('1–10 of 25'), findsOneWidget);
    expect(find.text('Page 1 of 3'), findsOneWidget);

    await tester.tap(find.text('NAME'));
    expect(q.sort, 'lastName');
    expect(q.order, 'asc');
    expect(changes, 1);

    await tester.tap(find.byTooltip('Next page'));
    expect(q.page, 2);

    // Header checkbox selects every row on the page.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(selected, {'id0', 'id1', 'id2'});
  });

  testWidgets('AdminDataTable shows empty, error and hidden columns', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var retried = false;
    await tester.pumpWidget(
      _wrap(
        AdminDataTable<Map<String, dynamic>>(
          columns: _cols(),
          rows: const [],
          idOf: (r) => '${r['id']}',
          query: TableQueryState(),
          total: 0,
          onQueryChanged: () {},
          error: 'boom',
          onRetry: () => retried = true,
          hiddenColumns: const {'status'},
        ),
      ),
    );
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('STATUS'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);

    await tester.pumpWidget(
      _wrap(AdminDataTable<Map<String, dynamic>>(columns: _cols(), rows: const [], idOf: (r) => '', query: TableQueryState(), total: 0, onQueryChanged: () {})),
    );
    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('StatusChip maps tones and exposes semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const Column(children: [StatusChip('suspended'), StatusChip('more_info_needed')])));
    expect(find.text('Suspended'), findsOneWidget);
    expect(find.text('More info needed'), findsOneWidget);
    expect(find.bySemanticsLabel('Status: Suspended'), findsOneWidget);
    expect(toneForStatus('approved'), Tone.success);
    expect(toneForStatus('overdue'), Tone.danger);
    handle.dispose();
  });

  testWidgets('EnvBadge renders environment label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Row(
          children: [
            EnvBadge(env: 'PROD'),
            EnvBadge(env: 'DEV'),
          ],
        ),
      ),
    );
    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
  });

  testWidgets('KpiCard is tappable and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          child: KpiCard(label: 'Open reports', value: '3', icon: Icons.flag, onTap: () => tapped = true),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Open reports: 3'), findsOneWidget);
    await tester.tap(find.byType(KpiCard));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('confirmAction requires a reason when asked', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await confirmAction(context, title: 'Suspend?', message: 'm', confirmLabel: 'Suspend', reasonLabel: 'Reason'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter at least 3 characters'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Overdue dues');
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();
    expect(result, 'Overdue dues');
  });

  testWidgets('login form validates before calling the API', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const AdminLoginPage()),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget); // production build: email not prefilled
    expect(find.text('Enter your password'), findsOneWidget);
  });

  test('both themes are available and gold accent is shared', () {
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.light.colorScheme.primary, AppTheme.dark.colorScheme.primary);
    expect(
      navGroups.expand((g) => g.items).map((i) => i.route),
      containsAll(['/overview', '/applications', '/members', '/dues', '/broadcast', '/audit', '/staff', '/settings']),
    );
  });

  test('humanize and initials helpers', () {
    expect(humanize('more_info_needed'), 'More info needed');
    expect(Avatar.initials('Alexander Whitmore'), 'AW');
    expect(Avatar.initials(''), '?');
  });
}
