import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';
import 'shell.dart';

const applicationStatuses = ['submitted', 'under_review', 'more_info_needed', 'approved', 'declined'];

/// Membership applications: server-side table with status facets, value
/// filter, multi-select bulk approve / decline and CSV export.
class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});
  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  final query = TableQueryState();
  List<Map<String, dynamic>> rows = [];
  Map<String, int> facets = {};
  int total = 0;
  bool loading = true;
  String? error;
  Set<String> selected = {};
  Set<String> hidden = {'source'};
  Set<String> statuses = {'submitted', 'under_review', 'more_info_needed'};
  int minValue = 0;
  bool busy = false;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> get _filters => {...query.toParams(), if (statuses.isNotEmpty) 'status': statuses.join(','), if (minValue > 0) 'minValue': minValue};

  Future<void> _load() async {
    final req = ++_req;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ref.read(adminRepositoryProvider).applicationsTable(_filters);
      if (!mounted || req != _req) return;
      setState(() {
        rows = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        total = (res['total'] as num?)?.toInt() ?? rows.length;
        facets = ((res['facets'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as num).toInt()));
      });
    } on Failure catch (e) {
      if (mounted && req == _req) setState(() => error = e.message);
    } finally {
      if (mounted && req == _req) setState(() => loading = false);
    }
  }

  Future<void> _bulk(String action) async {
    final n = selected.length;
    final approve = action == 'approve';
    final reason = await confirmAction(
      context,
      title: approve ? 'Approve $n application${n == 1 ? '' : 's'}?' : 'Decline $n application${n == 1 ? '' : 's'}?',
      message: approve
          ? 'Approved applicants receive a set-password email and become members. Already-decided applications are skipped.'
          : 'Applicants are notified by email. The reason is stored with the application and the audit log.',
      confirmLabel: approve ? 'Approve' : 'Decline',
      destructive: !approve,
      reasonLabel: approve ? null : 'Decline reason',
    );
    if (reason == null) return;
    setState(() => busy = true);
    try {
      final res = await ref.read(adminRepositoryProvider).bulkApplications(selected.toList(), action, reason: reason);
      final results = ((res['results'] as List?) ?? const []).cast<Map>();
      final ok = results.where((r) => r['ok'] == true).length;
      final failed = results.length - ok;
      if (!mounted) return;
      showToast(
        context,
        failed == 0 ? '$ok application${ok == 1 ? '' : 's'} ${approve ? 'approved' : 'declined'}' : '$ok processed · $failed skipped',
        kind: failed == 0 ? ToastKind.success : ToastKind.error,
      );
      setState(() => selected = {});
      ref.invalidate(consoleStatsProvider);
      await _load();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final params = {..._filters, if (selected.isNotEmpty) 'ids': selected.join(',')}
        ..remove('page')
        ..remove('pageSize');
      final csv = await ref.read(adminRepositoryProvider).applicationsCsv(params);
      final name = 'applications-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final ok = await downloadTextFile(name, csv);
      if (mounted) showToast(context, ok ? 'Exported $name' : 'CSV export is available in the web console', kind: ok ? ToastKind.success : ToastKind.info);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  List<TableColumn<Map<String, dynamic>>> get columns => [
    TableColumn(
      id: 'applicant',
      label: 'Applicant',
      flex: 3,
      minWidth: 220,
      sortKey: 'lastName',
      hideable: false,
      cell: (context, a) => Row(
        children: [
          Avatar(name: fullName(a), size: 34),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(fullName(a), style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
                    ),
                    if (a['foundingRequested'] == true) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Requested founding membership',
                        child: Icon(Icons.star_rounded, size: 14, color: context.tokens.accentText),
                      ),
                    ],
                  ],
                ),
                Text('${a['email']}', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
    TableColumn(
      id: 'vehicle',
      label: 'Vehicle',
      flex: 2,
      minWidth: 170,
      sortKey: 'vehicleYear',
      cell: (context, a) => Text(
        '${a['vehicleYear'] ?? ''} ${a['vehicleMake'] ?? ''} ${a['vehicleModel'] ?? ''}'.trim(),
        style: context.text.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    TableColumn(
      id: 'value',
      label: 'Est. value',
      width: 120,
      numeric: true,
      sortKey: 'vehicleEstimatedValue',
      cell: (context, a) => Text(fmtUsd(a['vehicleEstimatedValue'] as num?), style: context.text.titleSmall),
    ),
    TableColumn(
      id: 'location',
      label: 'Location',
      width: 150,
      cell: (context, a) => Text([a['city'], a['state']].where((e) => e != null).join(', '), style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
    ),
    TableColumn(
      id: 'source',
      label: 'Source',
      width: 120,
      cell: (context, a) =>
          Text(a['invite'] == null ? 'Direct' : 'Invite ${(a['invite'] as Map)['code']}', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
    ),
    TableColumn(
      id: 'proof',
      label: 'Proof',
      width: 80,
      cell: (context, a) {
        final n = ((a['proofMedia'] as List?) ?? const []).length;
        return Tooltip(
          message: n == 0 ? 'No ownership proof uploaded' : '$n file${n == 1 ? '' : 's'} uploaded',
          child: Row(
            children: [
              Icon(n == 0 ? Icons.attach_file_rounded : Icons.verified_outlined, size: 16, color: n == 0 ? context.tokens.textMuted : context.tokens.success),
              const SizedBox(width: 4),
              Text('$n', style: context.text.bodySmall),
            ],
          ),
        );
      },
    ),
    TableColumn(id: 'status', label: 'Status', width: 150, sortKey: 'status', cell: (_, a) => StatusChip('${a['status']}', dense: true)),
    TableColumn(
      id: 'submitted',
      label: 'Submitted',
      width: 120,
      sortKey: 'createdAt',
      cell: (context, a) => Tooltip(
        message: fmtDate(a['createdAt'], time: true),
        child: Text(fmtRelative(a['createdAt']), style: context.text.bodyMedium),
      ),
    ),
    TableColumn(
      id: 'go',
      label: '',
      width: 40,
      hideable: false,
      cell: (context, _) => Icon(Icons.chevron_right_rounded, color: context.tokens.textMuted),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pending = (facets['submitted'] ?? 0) + (facets['under_review'] ?? 0) + (facets['more_info_needed'] ?? 0);
    return PageScaffold(
      title: 'Applications',
      subtitle: '$pending awaiting a decision · approvals send a set-password email',
      actions: [
        ColumnVisibilityButton(columns: columns, hidden: hidden, onChanged: (h) => setState(() => hidden = h)),
        OutlinedButton.icon(
          onPressed: _exportCsv,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(selected.isEmpty ? 'Export CSV' : 'Export selected'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TableSearchField(
                hint: 'Search name or email',
                width: 280,
                onChanged: (v) {
                  query.q = v;
                  query.page = 1;
                  _load();
                },
              ),
              const SizedBox(width: Gap.xs),
              for (final s in applicationStatuses)
                FacetChip(
                  label: humanize(s),
                  count: facets[s] ?? 0,
                  selected: statuses.contains(s),
                  onSelected: (v) {
                    setState(() => v ? statuses.add(s) : statuses.remove(s));
                    query.page = 1;
                    _load();
                  },
                ),
              const SizedBox(width: Gap.xs),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: minValue,
                  decoration: const InputDecoration(labelText: 'Vehicle value', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Any value')),
                    DropdownMenuItem(value: 150000, child: Text(r'$150k+')),
                    DropdownMenuItem(value: 250000, child: Text(r'$250k+')),
                    DropdownMenuItem(value: 500000, child: Text(r'$500k+')),
                  ],
                  onChanged: (v) {
                    minValue = v ?? 0;
                    query.page = 1;
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          BulkActionBar(
            count: selected.length,
            onClear: () => setState(() => selected = {}),
            actions: [
              FilledButton.icon(onPressed: busy ? null : () => _bulk('approve'), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Approve')),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _bulk('decline'),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Decline'),
              ),
              OutlinedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Export CSV')),
            ],
          ),
          Expanded(
            child: AdminDataTable<Map<String, dynamic>>(
              columns: columns,
              rows: rows,
              idOf: (a) => '${a['id']}',
              rowLabel: (a) => '${fullName(a)}, ${humanize('${a['status']}')}',
              query: query,
              total: total,
              loading: loading,
              error: error,
              onRetry: _load,
              onQueryChanged: _load,
              hiddenColumns: hidden,
              selected: selected,
              onSelectionChanged: (s) => setState(() => selected = s),
              onRowTap: (a) => context.go('/applications/${a['id']}'),
              empty: const EmptyView(title: 'Inbox zero', message: 'No applications match these filters.', icon: Icons.mark_email_read_outlined),
            ),
          ),
        ],
      ),
    );
  }
}
