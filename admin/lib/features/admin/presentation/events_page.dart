import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';

enum _EventFilter { upcoming, drafts, past, all }

/// Events: responsive card grid with status, capacity and check-in progress,
/// plus a validated "Create event" dialog. In [checkinMode] the page lists
/// events to pick for door check-in.
class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key, this.checkinMode = false});
  final bool checkinMode;
  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  _EventFilter filter = _EventFilter.upcoming;
  String q = '';

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
      final list = await ref.read(adminRepositoryProvider).listEvents();
      items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  DateTime? _start(Map<String, dynamic> e) => DateTime.tryParse('${e['startsAt']}')?.toLocal();

  List<Map<String, dynamic>> get _visible {
    final now = DateTime.now();
    final list = items.where((e) {
      final s = _start(e);
      final past = s != null && s.isBefore(now.subtract(const Duration(hours: 6)));
      final ok = switch (widget.checkinMode ? _EventFilter.upcoming : filter) {
        _EventFilter.upcoming => !past && e['status'] != 'draft' && e['status'] != 'cancelled',
        _EventFilter.drafts => e['status'] == 'draft',
        _EventFilter.past => past || e['status'] == 'completed',
        _EventFilter.all => true,
      };
      return ok && (q.isEmpty || '${e['title']} ${e['venueName']}'.toLowerCase().contains(q.toLowerCase()));
    }).toList();
    list.sort((a, b) {
      final x = _start(a) ?? now, y = _start(b) ?? now;
      return filter == _EventFilter.past ? y.compareTo(x) : x.compareTo(y);
    });
    return list;
  }

  Future<void> _create() async {
    final created = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _CreateEventDialog());
    if (created == null) return;
    try {
      final res = await ref.read(adminRepositoryProvider).createEvent(created);
      if (!mounted) return;
      showToast(context, 'Draft event created', kind: ToastKind.success);
      context.go('/events/${res['id']}');
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return PageScaffold(
      title: widget.checkinMode ? 'Check-in' : 'Events',
      subtitle: widget.checkinMode ? 'Pick an event to open the door check-in scanner' : 'Plan evenings, track RSVPs and payments, run check-in',
      actions: [
        if (!widget.checkinMode) FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Create event')),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TableSearchField(hint: 'Search events', width: 280, onChanged: (v) => setState(() => q = v)),
              if (!widget.checkinMode)
                SegmentedButton<_EventFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _EventFilter.upcoming, label: Text('Upcoming')),
                    ButtonSegment(value: _EventFilter.drafts, label: Text('Drafts')),
                    ButtonSegment(value: _EventFilter.past, label: Text('Past')),
                    ButtonSegment(value: _EventFilter.all, label: Text('All')),
                  ],
                  selected: {filter},
                  onSelectionChanged: (s) => setState(() => filter = s.first),
                ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Expanded(
            child: loading
                ? const _GridSkeleton()
                : error != null
                ? ErrorView(message: error!, onRetry: _load)
                : visible.isEmpty
                ? EmptyView(
                    title: 'No events here',
                    message: widget.checkinMode ? 'There are no upcoming published events.' : 'Create an event to get started.',
                    icon: Icons.event_busy_outlined,
                    action: widget.checkinMode ? null : FilledButton(onPressed: _create, child: const Text('Create event')),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1200 ? 3 : (c.maxWidth >= 760 ? 2 : 1);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: Gap.lg,
                          crossAxisSpacing: Gap.lg,
                          mainAxisExtent: 214,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => _EventCard(
                          event: visible[i],
                          checkinMode: widget.checkinMode,
                          onTap: () => context.go(widget.checkinMode ? '/events/${visible[i]['id']}/checkin' : '/events/${visible[i]['id']}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.lg,
      runSpacing: Gap.lg,
      children: [for (var i = 0; i < 3; i++) const SizedBox(width: 360, child: SectionCard(child: SkeletonBox(height: 180)))],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap, this.checkinMode = false});
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  final bool checkinMode;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final start = DateTime.tryParse('${event['startsAt']}')?.toLocal();
    final counts = (event['_count'] as Map?) ?? const {};
    final going = (event['goingCount'] ?? counts['rsvps'] ?? 0) as num;
    final checkins = (counts['checkins'] ?? 0) as num;
    final cap = event['capacity'] as num?;
    final fee = event['feeUsdCents'] as num?;
    final ratio = cap == null || cap == 0 ? 0.0 : (going / cap).clamp(0.0, 1.0).toDouble();
    return Semantics(
      button: true,
      label: '${event['title']}, ${start == null ? '' : DateFormat.yMMMMEEEEd().add_jm().format(start)}, ${humanize('${event['status']}')}, $going going',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: t.surfaceRaised,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            start == null ? '—' : DateFormat('MMM').format(start).toUpperCase(),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: t.accentText),
                          ),
                          Text(
                            start == null ? '' : '${start.day}',
                            style: const TextStyle(fontFamily: AppFonts.serif, fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${event['title']}', style: context.text.headlineSmall?.copyWith(fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            start == null ? '' : '${DateFormat('EEE · h:mm a').format(start)}${event['venueName'] != null ? ' · ${event['venueName']}' : ''}',
                            style: context.text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((event['description'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: Gap.sm),
                            Text(
                              '${event['description']}',
                              style: context.text.bodySmall?.copyWith(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    StatusChip('${event['status']}', dense: true),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Text('RSVPS', style: context.text.labelSmall),
                    const Spacer(),
                    Text(cap == null ? '$going going' : '$going / $cap', style: context.text.titleSmall),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: t.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation(ratio > 0.9 ? t.warning : AppColors.gold),
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    _Meta(icon: Icons.payments_outlined, text: fee == null || fee == 0 ? 'Complimentary' : fmtUsd(fee, cents: true)),
                    const SizedBox(width: Gap.lg),
                    _Meta(icon: Icons.qr_code_2_rounded, text: '$checkins checked in'),
                    const Spacer(),
                    if (checkinMode)
                      FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.qr_code_scanner_rounded, size: 16), label: const Text('Open scanner'))
                    else
                      Icon(Icons.chevron_right_rounded, color: t.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.tokens.textMuted),
        const SizedBox(width: 5),
        Text(text, style: context.text.bodySmall?.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();
  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController();
  final venue = TextEditingController();
  final address = TextEditingController();
  final capacity = TextEditingController(text: '40');
  final fee = TextEditingController(text: '1000');
  DateTime date = DateTime.now().add(const Duration(days: 21));
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 0);

  @override
  void dispose() {
    for (final c in [title, venue, address, capacity, fee]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New event'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a title (3+ characters)' : null,
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (d != null) setState(() => date = d);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(DateFormat('EEE, MMM d, y').format(date)),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await showTimePicker(context: context, initialTime: time);
                        if (t != null) setState(() => time = t);
                      },
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: Text(time.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: venue,
                decoration: const InputDecoration(labelText: 'Venue'),
              ),
              const SizedBox(height: Gap.md),
              TextFormField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address (optional)'),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacity'),
                      validator: (v) => (v ?? '').isEmpty || (int.tryParse(v!) ?? 0) > 0 ? null : 'Positive number',
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: TextFormField(
                      controller: fee,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: r'Fee per member (USD)', prefixText: r'$ '),
                      validator: (v) => (v ?? '').isEmpty || (num.tryParse(v!) ?? -1) >= 0 ? null : 'Enter 0 or more',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text('The event is created as a draft. Publish it from the event page when ready.', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            final starts = DateTime(date.year, date.month, date.day, time.hour, time.minute);
            Navigator.pop(context, {
              'title': title.text.trim(),
              'startsAt': starts.toUtc().toIso8601String(),
              'status': 'draft',
              if (venue.text.trim().isNotEmpty) 'venueName': venue.text.trim(),
              if (address.text.trim().isNotEmpty) 'venueAddress': address.text.trim(),
              if (capacity.text.trim().isNotEmpty) 'capacity': int.parse(capacity.text.trim()),
              'feeUsdCents': ((num.tryParse(fee.text.trim()) ?? 0) * 100).round(),
            });
          },
          child: const Text('Create draft'),
        ),
      ],
    );
  }
}
