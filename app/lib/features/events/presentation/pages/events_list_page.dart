import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../widgets/event_card.dart';

enum _View { upcoming, calendar, past }

class EventsListPage extends ConsumerStatefulWidget {
  const EventsListPage({super.key});
  @override
  ConsumerState<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends ConsumerState<EventsListPage> {
  _View view = _View.upcoming;
  List<Map<String, dynamic>> upcoming = [];
  List<Map<String, dynamic>> past = [];
  List<Map<String, dynamic>> monthItems = [];
  bool loading = true;
  String? error;
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final r = await Future.wait([repo.list(filter: 'upcoming'), repo.list(filter: 'past')]);
      upcoming = r[0];
      past = r[1];
      await _loadMonth();
    } on Failure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load events.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadMonth() async {
    try {
      final cal = await ref.read(eventsRepositoryProvider).calendar(year: month.year, month: month.month);
      monthItems = ((cal['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      monthItems = [];
    }
    if (mounted) setState(() {});
  }

  void _open(Map<String, dynamic> e, {bool archive = false}) => context.push(archive ? '/events/${e['id']}/archive' : '/events/${e['id']}');

  Widget _grid(List<Map<String, dynamic>> items, {bool archive = false}) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: archive ? Icons.history : Icons.event_available_outlined,
            title: archive ? 'No past events yet' : 'No upcoming events',
            message: archive ? 'Recaps and galleries will appear here.' : 'New evenings are announced regularly — we\u2019ll notify you.',
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = gridColumns(c.maxWidth, minTile: 340, max: 3);
        return GridView.builder(
          padding: pagePadding(context, top: AppSpacing.md),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: 322 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.35),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => EventCard(
            event: items[i],
            onTap: () => _open(items[i], archive: archive),
          ),
        );
      },
    );
  }

  Widget _calendar() {
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final e in monthItems) {
      final s = DateTime.tryParse(e['startsAt']?.toString() ?? '')?.toLocal();
      if (s == null || s.year != month.year || s.month != month.month) continue;
      byDay.putIfAbsent(s.day, () => []).add(e);
    }
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final selected = selectedDay != null && selectedDay!.month == month.month ? byDay[selectedDay!.day] ?? [] : monthItems;
    final lux = context.lux;

    final grid = LuxCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () {
                  setState(() {
                    month = DateTime(month.year, month.month - 1);
                    selectedDay = null;
                  });
                  _loadMonth();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(DateFormat.yMMMM().format(month), textAlign: TextAlign.center, style: context.text.headlineSmall),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () {
                  setState(() {
                    month = DateTime(month.year, month.month + 1);
                    selectedDay = null;
                  });
                  _loadMonth();
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final l in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(l, style: context.text.labelSmall?.copyWith(color: lux.textMuted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++)
                Builder(
                  builder: (_) {
                    final ev = byDay[d] ?? const [];
                    final isToday = today.year == month.year && today.month == month.month && today.day == d;
                    final isSel = selectedDay?.day == d && selectedDay?.month == month.month;
                    return Semantics(
                      button: true,
                      selected: isSel,
                      label:
                          '${DateFormat.MMMMd().format(DateTime(month.year, month.month, d))}${ev.isEmpty ? '' : ', ${ev.length} event${ev.length > 1 ? 's' : ''}'}',
                      child: ExcludeSemantics(
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => selectedDay = isSel ? null : DateTime(month.year, month.month, d)),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel ? AppColors.gold : null,
                              border: isToday && !isSel ? Border.all(color: AppColors.gold) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$d',
                                  style: context.text.labelLarge?.copyWith(color: isSel ? AppColors.black : (ev.isEmpty ? lux.textMuted : lux.textPrimary)),
                                ),
                                if (ev.isNotEmpty)
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? AppColors.black : AppColors.gold),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(selectedDay == null ? 'This month' : DateFormat.MMMMEEEEd().format(selectedDay!)),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('No events on this day.', style: context.text.bodySmall),
          )
        else
          for (final e in selected)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _EventRow(event: e, onTap: () => _open(e)),
            ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 860) {
          return SingleChildScrollView(
            padding: pagePadding(context, top: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 420, child: grid),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: list),
              ],
            ),
          );
        }
        return ListView(
          padding: pagePadding(context, top: AppSpacing.md),
          children: [grid, list],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactSeg = context.screenWidth < 420;
    return CenteredContent(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.isCompact ? AppSpacing.lg : AppSpacing.xl,
              AppSpacing.lg,
              context.isCompact ? AppSpacing.lg : AppSpacing.xl,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_View>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _View.upcoming,
                    label: const Text('Upcoming', maxLines: 1, softWrap: false),
                    icon: compactSeg ? null : const Icon(Icons.event_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _View.calendar,
                    label: const Text('Calendar', maxLines: 1, softWrap: false),
                    icon: compactSeg ? null : const Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _View.past,
                    label: const Text('Past', maxLines: 1, softWrap: false),
                    icon: compactSeg ? null : const Icon(Icons.history, size: 18),
                  ),
                ],
                selected: {view},
                onSelectionChanged: (s) => setState(() => view = s.first),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? LayoutBuilder(
                    builder: (context, c) {
                      final cols = gridColumns(c.maxWidth, minTile: 340, max: 3);
                      return GridView.count(
                        crossAxisCount: cols,
                        padding: pagePadding(context),
                        mainAxisSpacing: AppSpacing.lg,
                        crossAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 1.15,
                        children: List.generate(cols * 2, (_) => const SkeletonCard(media: true, withAvatar: false, lines: 2)),
                      );
                    },
                  )
                : error != null
                ? ErrorState(message: error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      child: KeyedSubtree(
                        key: ValueKey(view),
                        child: switch (view) {
                          _View.upcoming => _grid(upcoming),
                          _View.calendar => _calendar(),
                          _View.past => _grid(past, archive: true),
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = DateTime.tryParse(event['startsAt']?.toString() ?? '')?.toLocal();
    return LuxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (s != null) DateBadge(date: s, size: 52),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['title']?.toString() ?? 'Event', style: context.text.titleMedium),
                Text(
                  [if (s != null) DateFormat.jm().format(s), event['venueName'] ?? ''].where((x) => '$x'.isNotEmpty).join(' · '),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
