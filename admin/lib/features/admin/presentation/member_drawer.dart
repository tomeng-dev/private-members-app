import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';
import 'member_dialogs.dart';

/// Right-side member detail drawer: profile, vehicles, dues, activity, audit.
class MemberDetailDrawer extends ConsumerStatefulWidget {
  const MemberDetailDrawer({super.key, required this.memberId, this.onChanged, this.asPage = false});
  final String memberId;

  /// Render inline (full page) instead of as a Drawer.
  final bool asPage;
  final VoidCallback? onChanged;

  @override
  ConsumerState<MemberDetailDrawer> createState() => _MemberDetailDrawerState();
}

class _MemberDetailDrawerState extends ConsumerState<MemberDetailDrawer> {
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final d = await ref.read(adminRepositoryProvider).memberDetail(widget.memberId);
      if (mounted) setState(() => data = d);
    } on Failure catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Map<String, dynamic> get profile => Map<String, dynamic>.from(data!['profile'] as Map);

  Future<void> _moderate(String action) async {
    final name = fullName(profile);
    final suspend = action == 'suspend';
    final reason = await confirmAction(
      context,
      title: suspend ? 'Suspend $name?' : 'Reinstate $name?',
      message: suspend
          ? 'They will be signed out and lose access to the app until reinstated. This is recorded in the audit log.'
          : 'They will regain access to the member app immediately.',
      confirmLabel: suspend ? 'Suspend member' : 'Reinstate',
      destructive: suspend,
      reasonLabel: 'Reason (recorded in audit log)',
    );
    if (reason == null) return;
    await _run(() => ref.read(adminRepositoryProvider).moderate(widget.memberId, action, reason), suspend ? 'Member suspended' : 'Member reinstated');
  }

  Future<void> _run(Future<void> Function() op, String ok) async {
    setState(() => busy = true);
    try {
      await op();
      if (!mounted) return;
      showToast(context, ok, kind: ToastKind.success);
      widget.onChanged?.call();
      await _load();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = SafeArea(
      child: data == null
          ? (error != null
                ? ErrorView(message: error!, onRetry: _load)
                : const Padding(
                    padding: EdgeInsets.all(Gap.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 64, height: 64, radius: 32),
                        SizedBox(height: Gap.lg),
                        SkeletonBox(width: 240, height: 22),
                        SizedBox(height: Gap.sm),
                        SkeletonBox(width: 180),
                        SizedBox(height: Gap.xl),
                        SkeletonBox(height: 200),
                      ],
                    ),
                  ))
          : DefaultTabController(
              length: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    tabs: [
                      const Tab(text: 'Profile'),
                      Tab(text: 'Vehicles (${(data!['vehicles'] as List).length})'),
                      const Tab(text: 'Dues'),
                      const Tab(text: 'Activity'),
                      Tab(text: 'Audit (${(data!['audit'] as List).length})'),
                    ],
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: t.canvas,
                      child: TabBarView(children: [_profileTab(), _vehiclesTab(), _duesTab(), _activityTab(), _auditTab()]),
                    ),
                  ),
                ],
              ),
            ),
    );
    if (widget.asPage) return Card(clipBehavior: Clip.antiAlias, child: content);
    return Drawer(width: 600, child: content);
  }

  Widget _header(BuildContext context) {
    final p = profile;
    final name = fullName(p);
    final suspended = p['status'] == 'suspended';
    final roles = ((p['roles'] as List?) ?? const []).map((e) => '$e').where((r) => r != 'member').toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.md, Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(name: name, size: 60, founding: p['foundingMember'] == true),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.text.headlineSmall),
                    const SizedBox(height: 2),
                    SelectableText('${p['email']}', style: context.text.bodySmall?.copyWith(fontSize: 13)),
                    const SizedBox(height: Gap.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip('${p['status']}', label: 'Account · ${humanize('${p['status']}')}', dense: true),
                        StatusChip('${p['membershipStatus']}', label: 'Dues · ${humanize('${p['membershipStatus']}')}', dense: true),
                        if (p['foundingMember'] == true) const StatusChip('founding', label: 'Founding', dense: true),
                        for (final r in roles) StatusChip(r, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.asPage) IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              if (suspended)
                FilledButton.icon(
                  onPressed: busy ? null : () => _moderate('reinstate'),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text('Reinstate'),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.tokens.danger,
                    side: BorderSide(color: context.tokens.danger.withValues(alpha: 0.5)),
                  ),
                  onPressed: busy ? null : () => _moderate('suspend'),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Suspend'),
                ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final changed = await showDuesDialog(context, ref, profile);
                        if (changed) {
                          widget.onChanged?.call();
                          await _load();
                        }
                      },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Dues & founding'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final changed = await showRolesDialog(context, ref, profile);
                        if (changed) {
                          widget.onChanged?.call();
                          await _load();
                        }
                      },
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Roles'),
              ),
              if (!widget.asPage)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    context.go('/members/${widget.memberId}');
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Full page'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pad(List<Widget> children) => ListView(padding: const EdgeInsets.all(Gap.xl), children: children);

  Widget _profileTab() {
    final p = profile;
    final b = data!['business'] as Map?;
    final c = (data!['activity'] as Map?)?['counts'] as Map? ?? const {};
    return _pad([
      if ((p['bio'] ?? '').toString().isNotEmpty) ...[SectionCard(child: Text('${p['bio']}', style: context.text.bodyMedium)), const SizedBox(height: Gap.lg)],
      SectionCard(
        title: 'Contact & company',
        child: Column(
          children: [
            InfoRow('Company', '${p['company'] ?? '—'}'),
            InfoRow('Title', '${p['title'] ?? '—'}'),
            InfoRow('Location', [p['city'], p['state']].where((e) => e != null && '$e'.isNotEmpty).join(', ').ifEmpty('—')),
            InfoRow('Phone', '${p['phone'] ?? '—'}'),
            InfoRow('Business page', b == null ? 'None' : '${b['name'] ?? b['companyName'] ?? 'Published'}'),
          ],
        ),
      ),
      const SizedBox(height: Gap.lg),
      SectionCard(
        title: 'Account',
        child: Column(
          children: [
            InfoRow('Member since', fmtDate(p['createdAt'])),
            InfoRow('Renewal date', fmtDate(p['renewalDate'])),
            InfoRow('Email verified', p['emailVerifiedAt'] == null ? 'No' : fmtDate(p['emailVerifiedAt'])),
            InfoRow('2FA', p['totpEnabledAt'] == null ? 'Not enabled' : 'Enabled ${fmtDate(p['totpEnabledAt'])}'),
            InfoRow(
              'Privacy',
              [
                if (p['showEmail'] == true) 'shows email',
                if (p['showPhone'] == true) 'shows phone',
                if (p['showEventsAttended'] == true) 'shows events',
              ].join(' · ').ifEmpty('Private'),
            ),
            InfoRow(
              'Activity',
              '${c['posts'] ?? 0} posts · ${c['comments'] ?? 0} comments · ${c['eventRsvps'] ?? 0} RSVPs · ${c['eventCheckins'] ?? 0} check-ins',
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _vehiclesTab() {
    final vs = (data!['vehicles'] as List).cast<Map>();
    if (vs.isEmpty) return const EmptyView(title: 'No vehicles', icon: Icons.directions_car_outlined);
    return _pad([
      for (final v in vs)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: SectionCard(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: context.tokens.surfaceRaised, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Icon(Icons.directions_car_filled_outlined, color: context.tokens.accentText),
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v['year']} ${v['make']} ${v['model']}', style: context.text.titleSmall),
                      Text(
                        [
                          if (v['color'] != null) '${v['color']}',
                          if (v['estimatedValueUsd'] != null) 'est. ${fmtUsd(v['estimatedValueUsd'] as num)}',
                          if (v['isPrimary'] == true) 'Primary',
                        ].join(' · '),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip('${v['verificationStatus']}', dense: true),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _duesTab() {
    final ds = (data!['dues'] as List).cast<Map>();
    final p = profile;
    return _pad([
      SectionCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEMBERSHIP', style: context.text.labelSmall),
                  const SizedBox(height: Gap.xs),
                  StatusChip('${p['membershipStatus']}'),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RENEWAL', style: context.text.labelSmall),
                  const SizedBox(height: Gap.xs),
                  Text(fmtDate(p['renewalDate']), style: context.text.titleSmall),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Gap.lg),
      if (ds.isEmpty)
        const EmptyView(title: 'No dues records', icon: Icons.receipt_long_outlined)
      else
        for (final d in ds)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: SectionCard(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtUsd(d['amountUsdCents'] as num?, cents: true), style: context.text.titleSmall),
                        Text(
                          [
                            fmtDate(d['createdAt']),
                            if (d['externalRef'] != null) 'ref ${d['externalRef']}',
                            if (d['notes'] != null) '${d['notes']}',
                          ].join(' · '),
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusChip('${d['status']}', dense: true),
                ],
              ),
            ),
          ),
    ]);
  }

  Widget _activityTab() {
    final a = (data!['activity'] as Map?) ?? const {};
    final posts = ((a['recentPosts'] as List?) ?? const []).cast<Map>();
    final rsvps = ((a['rsvps'] as List?) ?? const []).cast<Map>();
    return _pad([
      SectionCard(
        title: 'Event RSVPs',
        child: rsvps.isEmpty
            ? Text('No RSVPs yet.', style: context.text.bodySmall)
            : Column(
                children: [
                  for (final r in rsvps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${(r['event'] as Map?)?['title'] ?? 'Event'}', style: context.text.bodyMedium)),
                          Text(fmtDate((r['event'] as Map?)?['startsAt']), style: context.text.bodySmall),
                          const SizedBox(width: Gap.md),
                          StatusChip('${r['status']}', dense: true),
                          const SizedBox(width: 6),
                          if (r['paymentStatus'] != null) StatusChip('${r['paymentStatus']}', dense: true),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: Gap.lg),
      SectionCard(
        title: 'Recent posts',
        child: posts.isEmpty
            ? Text('No posts yet.', style: context.text.bodySmall)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in posts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                          Text(fmtDate(p['createdAt'], time: true), style: context.text.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ]);
  }

  Widget _auditTab() {
    final rows = (data!['audit'] as List).cast<Map>();
    if (rows.isEmpty) return const EmptyView(title: 'No audit entries', icon: Icons.history_rounded);
    return _pad([
      for (final a in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: SectionCard(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(humanize('${a['action']}'), style: context.text.titleSmall)),
                    Text(fmtDate(a['createdAt'], time: true), style: context.text.bodySmall),
                  ],
                ),
                const SizedBox(height: 2),
                Text('by ${a['actor'] == null ? 'system' : fullName(Map<String, dynamic>.from(a['actor'] as Map))}', style: context.text.bodySmall),
                if (a['metadata'] is Map && (a['metadata'] as Map).isNotEmpty) ...[
                  const SizedBox(height: Gap.xs),
                  Text(
                    (a['metadata'] as Map).entries.map((e) => '${e.key}: ${e.value}').join(' · '),
                    style: context.text.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
