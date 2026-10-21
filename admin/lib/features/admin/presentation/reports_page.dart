import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';
import 'shell.dart';

/// Moderation queue. [messagesOnly] shows reported direct messages; otherwise
/// posts, comments and members. Private DMs are never browsable — only the
/// reported message snapshot is shown.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, this.messagesOnly = false});
  final bool messagesOnly;
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String status = 'open';
  String type = 'all';
  String? selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReportsPage old) {
    super.didUpdateWidget(old);
    if (old.messagesOnly != widget.messagesOnly) {
      selectedId = null;
      type = 'all';
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await ref.read(adminRepositoryProvider).listReports(status: status);
      items = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((r) => (r['targetType'] == 'message') == widget.messagesOnly)
          .toList()
          .reversed
          .toList();
      if (selectedId != null && !items.any((r) => r['id'] == selectedId)) selectedId = null;
      selectedId ??= items.isEmpty ? null : '${items.first['id']}';
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible => type == 'all' ? items : items.where((r) => r['targetType'] == type).toList();

  Future<void> _resolve(Map<String, dynamic> r, {required bool hide}) async {
    final reason = await confirmAction(
      context,
      title: hide ? 'Hide reported ${r['targetType']}?' : 'Dismiss report?',
      message: hide
          ? 'The ${r['targetType']} will be hidden from members and the report marked resolved. This is recorded in the audit log.'
          : 'The report will be closed with no action taken.',
      confirmLabel: hide ? 'Hide & resolve' : 'Dismiss',
      destructive: hide,
      reasonLabel: 'Resolution note',
    );
    if (reason == null) return;
    try {
      await ref.read(adminRepositoryProvider).resolveReport('${r['id']}', {
        'decision': hide ? 'resolved' : 'dismissed',
        'hideContent': hide,
        'resolution': reason,
      });
      if (!mounted) return;
      showToast(context, hide ? 'Content hidden and report resolved' : 'Report dismissed', kind: ToastKind.success);
      ref.invalidate(consoleStatsProvider);
      await _load();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selected = visible.where((r) => r['id'] == selectedId).firstOrNull ?? visible.firstOrNull;
    return PageScaffold(
      title: widget.messagesOnly ? 'Message reports' : 'Content reports',
      subtitle: widget.messagesOnly
          ? 'Reported direct messages · moderators see only the reported message, never the conversation'
          : 'Reported posts, comments and members',
      actions: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'open', label: Text('Open')),
            ButtonSegment(value: 'resolved', label: Text('Resolved')),
            ButtonSegment(value: 'dismissed', label: Text('Dismissed')),
          ],
          selected: {status},
          onSelectionChanged: (s) {
            status = s.first;
            selectedId = null;
            _load();
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.messagesOnly) ...[
            Wrap(
              spacing: Gap.sm,
              children: [
                for (final t in const ['all', 'post', 'comment', 'user'])
                  FacetChip(
                    label: t == 'all' ? 'All types' : '${humanize(t)}s',
                    count: t == 'all' ? items.length : items.where((r) => r['targetType'] == t).length,
                    selected: type == t,
                    onSelected: (_) => setState(() => type = t),
                  ),
              ],
            ),
            const SizedBox(height: Gap.lg),
          ],
          Expanded(
            child: loading
                ? const Card(child: TableSkeleton(rows: 4))
                : error != null
                ? ErrorView(message: error!, onRetry: _load)
                : visible.isEmpty
                ? Card(
                    child: EmptyView(
                      title: status == 'open' ? 'Queue is clear' : 'Nothing here',
                      message: status == 'open' ? 'No open reports need attention.' : 'No $status reports.',
                      icon: Icons.verified_user_outlined,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 420,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) => _ReportTile(
                              report: visible[i],
                              selected: visible[i]['id'] == selected?['id'],
                              onTap: () => setState(() => selectedId = '${visible[i]['id']}'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.lg),
                      Expanded(
                        child: selected == null
                            ? const SizedBox.shrink()
                            : _ReportDetail(
                                report: selected,
                                onResolve: (hide) => _resolve(selected, hide: hide),
                                open: status == 'open',
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

IconData _typeIcon(String t) => switch (t) {
  'post' => Icons.article_outlined,
  'comment' => Icons.mode_comment_outlined,
  'user' => Icons.person_outline_rounded,
  'message' => Icons.chat_bubble_outline_rounded,
  _ => Icons.flag_outlined,
};

String _preview(Map<String, dynamic> r) {
  final m = (r['reportedPost'] ?? r['reportedComment'] ?? r['reportedMessage']) as Map?;
  if (m != null) return '${m['body'] ?? '(no text)'}';
  final u = r['reportedUser'] as Map?;
  if (u != null) return fullName(Map<String, dynamic>.from(u));
  return '${r['targetType']} ${r['targetId']}';
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.selected, required this.onTap});
  final Map<String, dynamic> report;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? AppColors.gold.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: selected
              ? const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
                )
              : null,
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.surfaceRaised, borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(_typeIcon('${report['targetType']}'), size: 18, color: t.accentText),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${report['reason']}'.replaceFirst('DEMO report: ', ''),
                            style: context.text.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(fmtRelative(report['createdAt']), style: context.text.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_preview(report), style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusChip('${report['targetType']}', tone: Tone.neutral, dense: true),
                        const SizedBox(width: 6),
                        Text('by ${fullName(Map<String, dynamic>.from((report['reporter'] as Map?) ?? const {}))}', style: context.text.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({required this.report, required this.onResolve, required this.open});
  final Map<String, dynamic> report;
  final ValueChanged<bool> onResolve;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final type = '${report['targetType']}';
    final content = (report['reportedPost'] ?? report['reportedComment'] ?? report['reportedMessage']) as Map?;
    final author = (content?['author'] ?? content?['sender']) as Map?;
    final user = report['reportedUser'] as Map?;
    final reporter = Map<String, dynamic>.from((report['reporter'] as Map?) ?? const {});
    return SectionCard(
      title: 'Reported ${humanize(type).toLowerCase()}',
      subtitle: 'Report filed ${fmtDate(report['createdAt'], time: true)}',
      trailing: StatusChip('${report['status']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: context.tokens.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: context.tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (author != null || user != null)
                  Row(
                    children: [
                      Avatar(name: fullName(Map<String, dynamic>.from((author ?? user)!)), size: 30),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName(Map<String, dynamic>.from((author ?? user)!)), style: context.text.titleSmall),
                            Text('${(author ?? user)!['email'] ?? ''}', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      if (user != null) StatusChip('${user['status']}', dense: true),
                      if (content?['hiddenAt'] != null || content?['deletedAt'] != null)
                        const StatusChip('hidden', label: 'Hidden', tone: Tone.warning, dense: true),
                    ],
                  ),
                if (content != null) ...[
                  const SizedBox(height: Gap.md),
                  SelectableText('${content['body'] ?? '(no text)'}', style: context.text.bodyLarge),
                  const SizedBox(height: Gap.sm),
                  Text(fmtDate(content['createdAt'], time: true), style: context.text.bodySmall),
                ],
                if (content == null && user == null) Text('The reported item is no longer available.', style: context.text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          InfoRow('Reason', '${report['reason']}'),
          InfoRow('Reported by', '${fullName(reporter)} · ${reporter['email'] ?? ''}'),
          if (report['resolution'] != null) InfoRow('Resolution', '${report['resolution']}'),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              if (open) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: context.tokens.danger, foregroundColor: Colors.white),
                  onPressed: () => onResolve(true),
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: Text(type == 'user' ? 'Resolve' : 'Hide content'),
                ),
                OutlinedButton.icon(onPressed: () => onResolve(false), icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Dismiss')),
              ],
              if (author != null || user != null)
                TextButton.icon(
                  onPressed: () => context.go('/members?open=${((author ?? user)!)['id']}'),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('Open member'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
