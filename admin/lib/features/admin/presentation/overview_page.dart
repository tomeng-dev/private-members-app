import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/di/providers.dart';
import '../../../core/ui/ui.dart';
import 'shell.dart';

final overviewKpisProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.read(adminRepositoryProvider).overview());

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(consoleStatsProvider);
    final kpis = ref.watch(overviewKpisProvider);
    final user = ref.watch(staffUserProvider);
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final first = user == null ? '' : fullName(user);

    Future<void> refresh() async {
      ref.invalidate(consoleStatsProvider);
      ref.invalidate(overviewKpisProvider);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: PageScaffold(
        scroll: true,
        title: first.isEmpty ? 'Overview' : '$greet, $first',
        subtitle: 'Club health at a glance · ${DateFormat('EEEE, MMMM d').format(DateTime.now())}',
        actions: [
          OutlinedButton.icon(onPressed: () => context.go('/broadcast'), icon: const Icon(Icons.campaign_outlined, size: 18), label: const Text('Broadcast')),
          FilledButton.icon(
            onPressed: () => context.go('/applications'),
            icon: const Icon(Icons.inbox_outlined, size: 18),
            label: const Text('Review applications'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            kpis.when(
              data: (k) => _KpiGrid(k: k),
              loading: () => const _KpiGrid(k: null),
              error: (e, _) => ErrorView(message: '$e', onRetry: refresh),
            ),
            const SizedBox(height: Gap.xl),
            stats.when(
              loading: () => const _ChartsSkeleton(),
              error: (e, _) => SectionCard(
                child: ErrorView(message: '$e', onRetry: refresh),
              ),
              data: (s) => _Dashboard(stats: s),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.k});
  final Map<String, dynamic>? k;

  @override
  Widget build(BuildContext context) {
    String v(String key) => k == null ? '—' : '${k![key] ?? 0}';
    final cards = [
      KpiCard(label: 'Active members', value: v('members'), icon: Icons.people_alt_outlined, onTap: () => context.go('/members')),
      KpiCard(
        label: 'Pending applications',
        value: v('pendingApplications'),
        icon: Icons.inbox_outlined,
        tone: Tone.info,
        onTap: () => context.go('/applications'),
      ),
      KpiCard(
        label: 'Upcoming events',
        value: v('upcomingEvents'),
        icon: Icons.event_available_outlined,
        tone: Tone.success,
        onTap: () => context.go('/events'),
      ),
      KpiCard(label: 'RSVPs going', value: v('rsvpsGoing'), icon: Icons.how_to_reg_outlined, tone: Tone.success, onTap: () => context.go('/events')),
      KpiCard(label: 'Dues outstanding', value: v('duesOverdue'), icon: Icons.receipt_long_outlined, tone: Tone.warning, onTap: () => context.go('/dues')),
      KpiCard(label: 'Open reports', value: v('openReports'), icon: Icons.flag_outlined, tone: Tone.danger, onTap: () => context.go('/reports')),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1250 ? 6 : (c.maxWidth >= 900 ? 3 : 2);
        const gap = Gap.lg;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }
}

class _ChartsSkeleton extends StatelessWidget {
  const _ChartsSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: SectionCard(child: SkeletonBox(height: 220))),
            SizedBox(width: Gap.lg),
            Expanded(child: SectionCard(child: SkeletonBox(height: 220))),
          ],
        ),
      ],
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.stats});
  final Map<String, dynamic> stats;

  List<Map<String, dynamic>> _list(String k) => ((stats[k] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Widget build(BuildContext context) {
    final apps = _list('applicationsPerWeek');
    final byMembership = _list('membersByMembership');
    final byStatus = _list('membersByStatus');
    final rsvps = _list('rsvpsPerUpcomingEvent');
    final checkins = _list('checkinsPerEvent');
    final activity = _list('recentActivity');
    final tasks = _list('pendingTasks');

    final appsCard = SectionCard(
      title: 'Applications per week',
      subtitle: 'Last 8 weeks · ${apps.fold<int>(0, (a, e) => a + ((e['count'] as num?)?.toInt() ?? 0))} total',
      child: SizedBox(height: 220, child: _WeeklyBars(data: apps)),
    );
    final membersCard = SectionCard(
      title: 'Members by status',
      subtitle: 'Membership standing · account status',
      child: SizedBox(
        height: 220,
        child: _MembershipDonut(byMembership: byMembership, byStatus: byStatus),
      ),
    );
    final rsvpCard = SectionCard(
      title: 'RSVPs per upcoming event',
      subtitle: 'Going vs capacity',
      trailing: TextButton(onPressed: () => context.go('/events'), child: const Text('All events')),
      child: rsvps.isEmpty ? const EmptyView(title: 'No upcoming events', icon: Icons.event_busy_outlined) : _CapacityBars(data: rsvps),
    );
    final checkinCard = SectionCard(
      title: 'Check-ins',
      subtitle: 'Recent events · checked in vs going',
      child: SizedBox(
        height: 220,
        child: checkins.isEmpty ? const EmptyView(title: 'No completed events yet', icon: Icons.qr_code_2_rounded) : _CheckinBars(data: checkins),
      ),
    );
    final tasksCard = SectionCard(
      title: 'Pending tasks',
      child: Column(children: [for (final t in tasks) _TaskTile(task: t)]),
    );
    final activityCard = SectionCard(
      title: 'Recent activity',
      trailing: TextButton(onPressed: () => context.go('/audit'), child: const Text('Audit log')),
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.md),
      child: activity.isEmpty
          ? const EmptyView(title: 'Nothing yet', icon: Icons.history_rounded)
          : Column(children: [for (final a in activity.take(8)) _ActivityTile(entry: a)]),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1100;
        Widget row(List<Widget> children, {List<int>? flex}) => wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: Gap.lg), Expanded(flex: flex?[i] ?? 1, child: children[i])],
                ],
              )
            : Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: Gap.lg), children[i]],
                ],
              );
        return Column(
          children: [
            row([appsCard, membersCard], flex: [3, 2]),
            const SizedBox(height: Gap.lg),
            row([rsvpCard, checkinCard], flex: [3, 2]),
            const SizedBox(height: Gap.lg),
            row([tasksCard, activityCard], flex: [2, 3]),
          ],
        );
      },
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.data});
  final List<Map<String, dynamic>> data;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxY = math.max(4, data.fold<int>(0, (a, e) => math.max(a, (e['count'] as num?)?.toInt() ?? 0)) + 1).toDouble();
    final summary = data.map((e) => '${e['week']}: ${e['count']}').join(', ');
    return Semantics(
      label: 'Bar chart of applications per week. $summary',
      excludeSemantics: true,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: math.max(1, (maxY / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.surfaceRaised,
              getTooltipItem: (g, _, rod, __) =>
                  BarTooltipItem('${rod.toY.toInt()} applications', TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(1, (maxY / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: context.text.bodySmall?.copyWith(fontSize: 11)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final d = DateTime.tryParse('${data[i]['week']}');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(d == null ? '' : DateFormat('MMM d').format(d), style: context.text.bodySmall?.copyWith(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: ((data[i]['count'] as num?) ?? 0).toDouble(),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.goldDark, i == data.length - 1 ? AppColors.champagne : AppColors.gold],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: t.surfaceSunken),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MembershipDonut extends StatelessWidget {
  const _MembershipDonut({required this.byMembership, required this.byStatus});
  final List<Map<String, dynamic>> byMembership;
  final List<Map<String, dynamic>> byStatus;

  @override
  Widget build(BuildContext context) {
    final total = byMembership.fold<int>(0, (a, e) => a + ((e['count'] as num?)?.toInt() ?? 0));
    Color colorFor(String s) => toneColor(context, toneForStatus(s));
    final summary = byMembership.map((e) => '${humanize('${e['status']}')} ${e['count']}').join(', ');
    return Semantics(
      label: 'Donut chart of members by membership status. $summary',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 58,
                    startDegreeOffset: -90,
                    sections: [
                      for (final e in byMembership)
                        PieChartSectionData(value: ((e['count'] as num?) ?? 0).toDouble(), color: colorFor('${e['status']}'), radius: 22, showTitle: false),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: context.text.headlineMedium),
                    Text('members', style: context.text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.lg),
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MEMBERSHIP', style: context.text.labelSmall),
                const SizedBox(height: Gap.xs),
                for (final e in byMembership) _Legend(color: colorFor('${e['status']}'), label: humanize('${e['status']}'), value: '${e['count']}'),
                const SizedBox(height: Gap.md),
                Text('ACCOUNT', style: context.text.labelSmall),
                const SizedBox(height: Gap.xs),
                for (final e in byStatus) _Legend(color: colorFor('${e['status']}'), label: humanize('${e['status']}'), value: '${e['count']}', hollow: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value, this.hollow = false});
  final Color color;
  final String label;
  final String value;
  final bool hollow;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: hollow ? null : color,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(label, style: context.text.bodySmall?.copyWith(color: context.tokens.textPrimary, fontSize: 13)),
          ),
          Text(value, style: context.text.titleSmall),
        ],
      ),
    );
  }
}

class _CapacityBars extends StatelessWidget {
  const _CapacityBars({required this.data});
  final List<Map<String, dynamic>> data;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        for (final e in data)
          Builder(
            builder: (context) {
              final going = (e['going'] as num?)?.toInt() ?? 0;
              final cap = (e['capacity'] as num?)?.toInt();
              final ratio = cap == null || cap == 0 ? 0.0 : (going / cap).clamp(0.0, 1.0);
              return Semantics(
                label: '${e['title']}: $going going${cap != null ? ' of $cap' : ''}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.md),
                  onTap: () => context.go('/events/${e['id']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.sm + 2, horizontal: Gap.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${e['title']}', style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
                            ),
                            Text(fmtDate(e['startsAt']), style: context.text.bodySmall),
                            const SizedBox(width: Gap.lg),
                            SizedBox(
                              width: 74,
                              child: Text(cap == null ? '$going going' : '$going / $cap', textAlign: TextAlign.right, style: context.text.titleSmall),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.pill),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: t.surfaceSunken,
                            valueColor: AlwaysStoppedAnimation(ratio > 0.9 ? t.warning : AppColors.gold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _CheckinBars extends StatelessWidget {
  const _CheckinBars({required this.data});
  final List<Map<String, dynamic>> data;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxY = math.max(4, data.fold<int>(0, (a, e) => math.max(a, (e['going'] as num?)?.toInt() ?? 0)) + 1).toDouble();
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: 'Check-ins per event. ${data.map((e) => '${e['title']}: ${e['checkins']} of ${e['going']}').join(', ')}',
            excludeSemantics: true,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1, dashArray: [4, 4]),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: math.max(1, (maxY / 4).ceilToDouble()),
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: context.text.bodySmall?.copyWith(fontSize: 11)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        final title = '${data[i]['title']}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(title.length > 18 ? '${title.substring(0, 17)}…' : title, style: context.text.bodySmall?.copyWith(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(
                          toY: ((data[i]['going'] as num?) ?? 0).toDouble(),
                          width: 18,
                          color: t.surfaceSunken,
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: t.border),
                        ),
                        BarChartRodData(
                          toY: ((data[i]['checkins'] as num?) ?? 0).toDouble(),
                          width: 18,
                          color: t.success,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              child: _Legend(color: t.textMuted, label: 'Going', value: '', hollow: true),
            ),
            const SizedBox(width: Gap.lg),
            SizedBox(
              width: 110,
              child: _Legend(color: t.success, label: 'Checked in', value: ''),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final Map<String, dynamic> task;
  @override
  Widget build(BuildContext context) {
    final count = (task['count'] as num?)?.toInt() ?? 0;
    final icon = switch ('${task['key']}') {
      'applications' => Icons.inbox_outlined,
      'vehicles' => Icons.verified_outlined,
      'reports' => Icons.flag_outlined,
      'dues' => Icons.receipt_long_outlined,
      _ => Icons.task_alt_rounded,
    };
    final done = count == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Material(
        color: context.tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () => context.go('${task['route'] ?? '/overview'}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
            child: Row(
              children: [
                Icon(done ? Icons.check_circle_outline_rounded : icon, size: 20, color: done ? context.tokens.success : context.tokens.accentText),
                const SizedBox(width: Gap.md),
                Expanded(child: Text('${task['label']}', style: context.text.bodyMedium)),
                if (done)
                  Text('All clear', style: context.text.bodySmall)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                const SizedBox(width: Gap.sm),
                Icon(Icons.chevron_right_rounded, size: 18, color: context.tokens.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});
  final Map<String, dynamic> entry;

  IconData get _icon {
    final a = '${entry['action']}';
    if (a.startsWith('auth')) return Icons.login_rounded;
    if (a.startsWith('application')) return Icons.inbox_outlined;
    if (a.startsWith('member')) return Icons.person_outline_rounded;
    if (a.startsWith('event')) return Icons.event_outlined;
    if (a.startsWith('notification')) return Icons.campaign_outlined;
    if (a.startsWith('report') || a.startsWith('moderation')) return Icons.shield_outlined;
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final actor = entry['actor'] as Map?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: context.tokens.surfaceRaised, borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(_icon, size: 16, color: context.tokens.textMuted),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: actor == null ? 'System' : fullName(Map<String, dynamic>.from(actor)), style: context.text.titleSmall),
                  TextSpan(
                    text: '  ${humanize('${entry['action']}')}',
                    style: context.text.bodyMedium?.copyWith(color: context.tokens.textMuted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(fmtRelative(entry['createdAt']), style: context.text.bodySmall),
        ],
      ),
    );
  }
}
