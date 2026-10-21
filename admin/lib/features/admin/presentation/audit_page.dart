import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';

/// Audit log: filter by action prefix and date range, export the visible rows.
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});
  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String action = '';
  DateTimeRange? range;
  String? expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await ref
          .read(adminRepositoryProvider)
          .auditLogsFiltered(
            action: action,
            from: range?.start.toUtc().toIso8601String(),
            to: range?.end.add(const Duration(days: 1)).toUtc().toIso8601String(),
          );
      items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _export() async {
    String esc(Object? v) {
      var s = '${v ?? ''}';
      if (RegExp(r'^[=+\-@]').hasMatch(s)) {
        s = "'$s";
      }
      return '"${s.replaceAll('"', '""')}"';
    }

    final lines = [
      'createdAt,actor,action,targetType,targetId,ip',
      for (final a in items) [a['createdAt'], (a['actor'] as Map?)?['email'], a['action'], a['targetType'], a['targetId'], a['ipAddress']].map(esc).join(','),
    ];
    final ok = await downloadTextFile('audit-${DateTime.now().toIso8601String().substring(0, 10)}.csv', lines.join('\n'));
    if (mounted) {
      showToast(context, ok ? 'Exported ${items.length} entries' : 'CSV export is available in the web console', kind: ok ? ToastKind.success : ToastKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PageScaffold(
      title: 'Audit log',
      subtitle: 'Every administrative action, newest first',
      actions: [
        OutlinedButton.icon(onPressed: items.isEmpty ? null : _export, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Export CSV')),
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
                hint: 'Filter by action, e.g. member. or application.approved',
                width: 380,
                onChanged: (v) {
                  action = v.trim();
                  _load();
                },
              ),
              for (final p in const ['auth', 'application', 'member', 'event', 'notification', 'report'])
                FacetChip(
                  label: humanize(p),
                  selected: action == p,
                  onSelected: (v) {
                    action = v ? p : '';
                    _load();
                  },
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: range,
                  );
                  if (r != null) {
                    range = r;
                    _load();
                  }
                },
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(range == null ? 'Any date' : '${fmtDate(range!.start.toIso8601String())} – ${fmtDate(range!.end.toIso8601String())}'),
              ),
              if (range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  onPressed: () {
                    range = null;
                    _load();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: loading
                  ? const TableSkeleton()
                  : error != null
                  ? ErrorView(message: error!, onRetry: _load)
                  : items.isEmpty
                  ? const EmptyView(title: 'No entries', message: 'Nothing matches these filters.', icon: Icons.history_toggle_off_rounded)
                  : Column(
                      children: [
                        Container(
                          height: 44,
                          color: t.surfaceRaised,
                          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                          child: Row(
                            children: [
                              SizedBox(width: 180, child: Text('WHEN', style: context.text.labelMedium)),
                              Expanded(flex: 2, child: Text('ACTOR', style: context.text.labelMedium)),
                              Expanded(flex: 2, child: Text('ACTION', style: context.text.labelMedium)),
                              Expanded(flex: 2, child: Text('TARGET', style: context.text.labelMedium)),
                              SizedBox(width: 130, child: Text('IP', style: context.text.labelMedium)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final a = items[i];
                              final open = expandedId == a['id'];
                              final meta = a['metadata'];
                              return InkWell(
                                onTap: () => setState(() => expandedId = open ? null : '${a['id']}'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 180,
                                            child: Text(fmtDate(a['createdAt'], time: true), style: context.text.bodySmall?.copyWith(fontSize: 13)),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Avatar(name: a['actor'] == null ? 'System' : fullName(Map<String, dynamic>.from(a['actor'] as Map)), size: 26),
                                                const SizedBox(width: Gap.sm),
                                                Expanded(
                                                  child: Text(
                                                    a['actor'] == null ? 'System' : fullName(Map<String, dynamic>.from(a['actor'] as Map)),
                                                    style: context.text.bodyMedium,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: t.surfaceRaised,
                                                  borderRadius: BorderRadius.circular(Radii.sm),
                                                  border: Border.all(color: t.border),
                                                ),
                                                child: Text('${a['action']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              a['targetType'] == null ? '—' : '${a['targetType']} ${'${a['targetId'] ?? ''}'.split('-').first}',
                                              style: context.text.bodySmall?.copyWith(fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 130, child: Text('${a['ipAddress'] ?? '—'}', style: context.text.bodySmall)),
                                        ],
                                      ),
                                      if (open && meta != null) ...[
                                        const SizedBox(height: Gap.sm),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(Gap.md),
                                          decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(Radii.sm)),
                                          child: SelectableText('$meta', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
