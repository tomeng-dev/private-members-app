import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';
import 'member_dialogs.dart';
import 'member_drawer.dart';
import 'shell.dart';

enum MembersView { all, dues, staff }

/// Server-side members table with filters, column visibility, selection,
/// bulk actions (suspend / reinstate / CSV) and a right-side detail drawer.
/// The same page powers Members, Dues and Staff & roles with different presets.
class MembersTablePage extends ConsumerStatefulWidget {
  const MembersTablePage({super.key, this.view = MembersView.all, this.openId});
  final MembersView view;
  final String? openId;

  @override
  ConsumerState<MembersTablePage> createState() => _MembersTablePageState();
}

class _MembersTablePageState extends ConsumerState<MembersTablePage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final query = TableQueryState(sort: 'createdAt');
  List<Map<String, dynamic>> rows = [];
  int total = 0;
  bool loading = true;
  String? error;
  Set<String> selected = {};
  Set<String> hidden = {'joined', 'company', 'city'};
  String? status;
  late String? membership = switch (widget.view) {
    MembersView.dues => 'dues_due,overdue',
    _ => null,
  };
  bool founding = false;
  late String? role = widget.view == MembersView.staff ? 'moderator,admin,super_admin' : null;
  String? drawerId;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    if (widget.view == MembersView.dues) query.sort = 'renewalDate';
    if (widget.view == MembersView.dues) query.order = 'asc';
    _load();
    if (widget.openId != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(widget.openId!));
  }

  @override
  void didUpdateWidget(covariant MembersTablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openId != null && widget.openId != oldWidget.openId) _open(widget.openId!);
  }

  Map<String, dynamic> get _filters => {
    ...query.toParams(),
    if (status != null) 'status': status,
    if (membership != null) 'membershipStatus': membership,
    if (founding) 'founding': 'true',
    if (role != null) 'role': role,
  };

  Future<void> _load() async {
    final req = ++_req;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ref.read(adminRepositoryProvider).membersTable(_filters);
      if (!mounted || req != _req) return;
      setState(() {
        rows = ((res['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        total = (res['total'] as num?)?.toInt() ?? rows.length;
      });
    } on Failure catch (e) {
      if (mounted && req == _req) setState(() => error = e.message);
    } finally {
      if (mounted && req == _req) setState(() => loading = false);
    }
  }

  void _open(String id) {
    setState(() => drawerId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scaffold.currentState?.openEndDrawer());
  }

  void _changed() {
    ref.invalidate(consoleStatsProvider);
    _load();
  }

  Future<void> _bulk(String action) async {
    final suspend = action == 'suspend';
    final n = selected.length;
    final reason = await confirmAction(
      context,
      title: suspend ? 'Suspend $n member${n == 1 ? '' : 's'}?' : 'Reinstate $n member${n == 1 ? '' : 's'}?',
      message: suspend
          ? 'Suspended members lose access immediately. You cannot suspend yourself or a super admin.'
          : 'Selected members regain access to the member app.',
      confirmLabel: suspend ? 'Suspend' : 'Reinstate',
      destructive: suspend,
      reasonLabel: 'Reason (recorded in audit log)',
    );
    if (reason == null) return;
    try {
      final res = await ref.read(adminRepositoryProvider).bulkMembers(selected.toList(), action, reason);
      final results = ((res['results'] as List?) ?? const []).cast<Map>();
      final ok = results.where((r) => r['ok'] == true).length;
      final failed = results.length - ok;
      if (!mounted) return;
      showToast(
        context,
        failed == 0
            ? '$ok member${ok == 1 ? '' : 's'} ${suspend ? 'suspended' : 'reinstated'}'
            : '$ok succeeded · $failed skipped (${results.firstWhere((r) => r['ok'] != true)['error']})',
        kind: failed == 0 ? ToastKind.success : ToastKind.error,
      );
      setState(() => selected = {});
      _changed();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final params = {..._filters, if (selected.isNotEmpty) 'ids': selected.join(',')}
        ..remove('page')
        ..remove('pageSize');
      final csv = await ref.read(adminRepositoryProvider).membersCsv(params);
      final name = 'members-${DateTime.now().toIso8601String().substring(0, 10)}.csv';
      final ok = await downloadTextFile(name, csv);
      if (mounted) showToast(context, ok ? 'Exported $name' : 'CSV export is available in the web console', kind: ok ? ToastKind.success : ToastKind.info);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _markPaid(Map<String, dynamic> m) async {
    final ok = await confirmAction(
      context,
      title: 'Mark dues paid?',
      message: '${fullName(m)} will be set to Active and the change recorded in the audit log.',
      confirmLabel: 'Mark paid',
    );
    if (ok == null) return;
    try {
      await ref.read(adminRepositoryProvider).updateDues(m['id'] as String, {'membershipStatus': 'active'});
      if (mounted) showToast(context, 'Dues marked paid', kind: ToastKind.success);
      _changed();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  List<TableColumn<Map<String, dynamic>>> get columns => [
    TableColumn(
      id: 'member',
      label: 'Member',
      flex: 3,
      minWidth: 220,
      sortKey: 'lastName',
      hideable: false,
      cell: (context, m) => Row(
        children: [
          Avatar(name: fullName(m), founding: m['foundingMember'] == true, size: 34),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName(m), style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
                Text('${m['email']}', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
    TableColumn(id: 'status', label: 'Account', width: 130, sortKey: 'status', cell: (_, m) => StatusChip('${m['status']}', dense: true)),
    TableColumn(
      id: 'membership',
      label: 'Membership',
      width: 140,
      sortKey: 'membershipStatus',
      cell: (_, m) => StatusChip('${m['membershipStatus']}', dense: true),
    ),
    TableColumn(
      id: 'roles',
      label: 'Roles',
      width: 150,
      cell: (context, m) {
        final roles = ((m['roles'] as List?) ?? const []).map((e) => '$e').where((r) => r != 'member').toList();
        if (roles.isEmpty) return Text('Member', style: Theme.of(context).textTheme.bodySmall);
        return Wrap(spacing: 4, runSpacing: 4, children: [for (final r in roles.take(2)) StatusChip(r, dense: true)]);
      },
    ),
    TableColumn(
      id: 'vehicle',
      label: 'Primary vehicle',
      flex: 2,
      minWidth: 160,
      cell: (context, m) => Text('${m['primaryVehicle'] ?? '—'}', style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
    ),
    TableColumn(
      id: 'company',
      label: 'Company',
      flex: 2,
      minWidth: 160,
      cell: (context, m) => Text('${m['company'] ?? '—'}', style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
    ),
    TableColumn(
      id: 'city',
      label: 'Location',
      width: 150,
      cell: (context, m) => Text([m['city'], m['state']].where((e) => e != null).join(', '), style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
    ),
    TableColumn(
      id: 'renewal',
      label: 'Renewal',
      width: 120,
      sortKey: 'renewalDate',
      cell: (context, m) => Text(fmtDate(m['renewalDate']), style: context.text.bodyMedium),
    ),
    TableColumn(
      id: 'joined',
      label: 'Joined',
      width: 120,
      sortKey: 'createdAt',
      cell: (context, m) => Text(fmtDate(m['createdAt']), style: context.text.bodyMedium),
    ),
    TableColumn(
      id: 'actions',
      label: '',
      width: widget.view == MembersView.all ? 56 : 130,
      hideable: false,
      numeric: true,
      cell: (context, m) => switch (widget.view) {
        MembersView.dues =>
          m['membershipStatus'] == 'active' ? const SizedBox.shrink() : OutlinedButton(onPressed: () => _markPaid(m), child: const Text('Mark paid')),
        MembersView.staff => OutlinedButton(
          onPressed: () async {
            if (await showRolesDialog(context, ref, m)) _changed();
          },
          child: const Text('Edit roles'),
        ),
        MembersView.all => Icon(Icons.chevron_right_rounded, color: context.tokens.textMuted),
      },
    ),
  ];

  Widget _filterBar() {
    Widget dropdown(String label, String? value, List<(String?, String)> options, ValueChanged<String?> onChanged) {
      return MenuAnchor(
        menuChildren: [
          for (final o in options)
            MenuItemButton(
              leadingIcon: Icon(value == o.$1 ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 16),
              onPressed: () => onChanged(o.$1),
              child: Text(o.$2),
            ),
        ],
        builder: (context, ctrl, _) => FilterChip(
          selected: value != null,
          showCheckmark: false,
          avatar: Icon(Icons.filter_list_rounded, size: 16, color: value != null ? context.tokens.accentText : context.tokens.textMuted),
          label: Text(value == null ? label : '$label: ${options.firstWhere((o) => o.$1 == value, orElse: () => (value, humanize(value))).$2}'),
          onSelected: (_) => ctrl.isOpen ? ctrl.close() : ctrl.open(),
        ),
      );
    }

    final children = <Widget>[
      TableSearchField(
        hint: 'Search name, email, company, city',
        onChanged: (v) {
          query.q = v;
          query.page = 1;
          _load();
        },
      ),
      dropdown('Account', status, const [(null, 'Any'), ('active', 'Active'), ('suspended', 'Suspended'), ('pending_password', 'Pending password')], (v) {
        status = v;
        query.page = 1;
        _load();
      }),
      if (widget.view != MembersView.dues)
        dropdown('Membership', membership, const [(null, 'Any'), ('active', 'Active'), ('dues_due', 'Dues due'), ('overdue', 'Overdue')], (v) {
          membership = v;
          query.page = 1;
          _load();
        })
      else
        dropdown('Dues', membership, const [('dues_due,overdue', 'Due or overdue'), ('dues_due', 'Dues due'), ('overdue', 'Overdue'), (null, 'All members')], (
          v,
        ) {
          membership = v;
          query.page = 1;
          _load();
        }),
      if (widget.view != MembersView.staff)
        dropdown('Role', role, const [(null, 'Any'), ('moderator', 'Moderator'), ('admin', 'Admin'), ('super_admin', 'Super admin')], (v) {
          role = v;
          query.page = 1;
          _load();
        })
      else
        dropdown(
          'Role',
          role,
          const [('moderator,admin,super_admin', 'All staff'), ('moderator', 'Moderators'), ('admin', 'Admins'), ('super_admin', 'Super admins')],
          (v) {
            role = v ?? 'moderator,admin,super_admin';
            query.page = 1;
            _load();
          },
        ),
      FilterChip(
        label: const Text('Founding only'),
        selected: founding,
        avatar: Icon(Icons.star_rounded, size: 16, color: founding ? context.tokens.accentText : context.tokens.textMuted),
        showCheckmark: false,
        onSelected: (v) {
          founding = v;
          query.page = 1;
          _load();
        },
      ),
    ];
    return Wrap(spacing: Gap.sm, runSpacing: Gap.sm, crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (widget.view) {
      MembersView.all => ('Members', '$total members · search, filter and manage accounts'),
      MembersView.dues => ('Dues', 'Members with outstanding dues · mark payments as received'),
      MembersView.staff => ('Staff & roles', 'Moderators and administrators · role changes are audit-logged'),
    };
    return Scaffold(
      key: _scaffold,
      backgroundColor: Colors.transparent,
      endDrawer: drawerId == null ? null : MemberDetailDrawer(key: ValueKey(drawerId), memberId: drawerId!, onChanged: _changed),
      onEndDrawerChanged: (open) {
        if (!open) setState(() => drawerId = drawerId);
      },
      body: PageScaffold(
        title: title,
        subtitle: subtitle,
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
            _filterBar(),
            const SizedBox(height: Gap.lg),
            BulkActionBar(
              count: selected.length,
              onClear: () => setState(() => selected = {}),
              actions: [
                OutlinedButton.icon(onPressed: () => _bulk('suspend'), icon: const Icon(Icons.block_rounded, size: 18), label: const Text('Suspend')),
                OutlinedButton.icon(onPressed: () => _bulk('reinstate'), icon: const Icon(Icons.restore_rounded, size: 18), label: const Text('Reinstate')),
                OutlinedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Export CSV')),
              ],
            ),
            Expanded(
              child: AdminDataTable<Map<String, dynamic>>(
                columns: columns,
                rows: rows,
                idOf: (m) => '${m['id']}',
                rowLabel: (m) => fullName(m),
                query: query,
                total: total,
                loading: loading,
                error: error,
                onRetry: _load,
                onQueryChanged: _load,
                hiddenColumns: hidden,
                selected: selected,
                activeRowId: drawerId,
                onSelectionChanged: (s) => setState(() => selected = s),
                onRowTap: (m) => _open('${m['id']}'),
                empty: EmptyView(
                  title: widget.view == MembersView.dues ? 'No outstanding dues' : 'No members match',
                  message: widget.view == MembersView.dues ? 'Every member is paid up.' : 'Try a different search or clear the filters.',
                  icon: widget.view == MembersView.dues ? Icons.task_alt_rounded : Icons.person_search_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
