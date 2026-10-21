import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';

const _segments = [
  ('all', 'All active members', 'Everyone with an active account', Icons.groups_2_outlined),
  ('founding', 'Founding members', 'Members flagged as founding', Icons.star_outline_rounded),
  ('dues_due', 'Dues due', 'Renewal payment is due', Icons.receipt_long_outlined),
  ('overdue', 'Dues overdue', 'Renewal payment is overdue', Icons.warning_amber_rounded),
  ('event_rsvps', 'Event attendees', 'Members going to a specific event', Icons.event_available_outlined),
];

/// Compose and send a notification to a member segment (push / email / in-app),
/// with an audience estimate (dry run) and a confirmation step.
class BroadcastPage extends ConsumerStatefulWidget {
  const BroadcastPage({super.key});
  @override
  ConsumerState<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends ConsumerState<BroadcastPage> {
  final _form = GlobalKey<FormState>();
  final title = TextEditingController();
  final body = TextEditingController();
  String segment = 'all';
  String? eventId;
  final channels = <String>{'in_app', 'push'};
  List<Map<String, dynamic>> events = [];
  int? audience;
  bool estimating = false;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    title.addListener(() => setState(() {}));
    body.addListener(() => setState(() {}));
    ref
        .read(adminRepositoryProvider)
        .listEvents()
        .then((list) {
          if (!mounted) return;
          setState(() => events = list.map((e) => Map<String, dynamic>.from(e as Map)).where((e) => e['status'] == 'published').toList());
        })
        .catchError((_) {});
    _estimate();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload({required bool dryRun}) => {
    'title': title.text.trim().isEmpty ? 'Preview' : title.text.trim(),
    'body': body.text.trim().isEmpty ? 'Preview' : body.text.trim(),
    'segment': segment,
    if (segment == 'event_rsvps' && eventId != null) 'eventId': eventId,
    'channels': channels.toList(),
    'dryRun': dryRun,
  };

  Future<void> _estimate() async {
    if (segment == 'event_rsvps' && eventId == null) {
      setState(() => audience = null);
      return;
    }
    setState(() => estimating = true);
    try {
      final res = await ref.read(adminRepositoryProvider).broadcast(_payload(dryRun: true));
      if (mounted) setState(() => audience = (res['recipients'] as num?)?.toInt());
    } on Failure catch (_) {
      if (mounted) setState(() => audience = null);
    } finally {
      if (mounted) setState(() => estimating = false);
    }
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (channels.isEmpty) {
      showToast(context, 'Choose at least one channel', kind: ToastKind.error);
      return;
    }
    await _estimate();
    if (!mounted) return;
    final seg = _segments.firstWhere((s) => s.$1 == segment);
    final ok = await confirmAction(
      context,
      title: 'Send to ${audience ?? 0} member${audience == 1 ? '' : 's'}?',
      message: '“${title.text.trim()}” will be sent to ${seg.$2.toLowerCase()} via ${channels.map(_channelLabel).join(', ')}. This cannot be undone.',
      confirmLabel: 'Send broadcast',
    );
    if (ok == null) return;
    setState(() => sending = true);
    try {
      final res = await ref.read(adminRepositoryProvider).broadcast(_payload(dryRun: false));
      if (!mounted) return;
      showToast(context, 'Broadcast sent to ${res['recipients']} members', kind: ToastKind.success);
      title.clear();
      body.clear();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  static String _channelLabel(String c) => switch (c) {
    'in_app' => 'in-app',
    'push' => 'push',
    'email' => 'email',
    _ => c,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final form = Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Audience',
            subtitle: 'Only active members receive broadcasts',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in _segments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: _SegmentTile(
                      icon: s.$4,
                      title: s.$2,
                      subtitle: s.$3,
                      selected: segment == s.$1,
                      onTap: () {
                        setState(() => segment = s.$1);
                        _estimate();
                      },
                    ),
                  ),
                if (segment == 'event_rsvps')
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.sm),
                    child: DropdownButtonFormField<String>(
                      initialValue: eventId,
                      decoration: const InputDecoration(labelText: 'Event'),
                      items: [
                        for (final e in events)
                          DropdownMenuItem(
                            value: '${e['id']}',
                            child: Text('${e['title']} · ${fmtDate(e['startsAt'])}', overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      validator: (v) => segment == 'event_rsvps' && v == null ? 'Choose an event' : null,
                      onChanged: (v) {
                        setState(() => eventId = v);
                        _estimate();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          SectionCard(
            title: 'Message',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Founders Dinner — seats are going fast'),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a title (3+ characters)' : null,
                ),
                const SizedBox(height: Gap.sm),
                TextFormField(
                  controller: body,
                  maxLength: 1000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a message' : null,
                ),
                const SizedBox(height: Gap.sm),
                Text('CHANNELS', style: context.text.labelSmall),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    for (final c in const [
                      ('in_app', 'In-app', Icons.notifications_none_rounded),
                      ('push', 'Push', Icons.phone_iphone_rounded),
                      ('email', 'Email', Icons.mail_outline_rounded),
                    ])
                      FilterChip(
                        avatar: Icon(c.$3, size: 16, color: channels.contains(c.$1) ? t.accentText : t.textMuted),
                        label: Text(c.$2),
                        selected: channels.contains(c.$1),
                        showCheckmark: false,
                        onSelected: (v) => setState(() => v ? channels.add(c.$1) : channels.remove(c.$1)),
                      ),
                  ],
                ),
                if (channels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.sm),
                    child: Text('Choose at least one channel', style: TextStyle(color: t.danger, fontSize: 12.5)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Estimated reach',
          child: Row(
            children: [
              Text(estimating ? '…' : (audience == null ? '—' : '$audience'), style: context.text.displaySmall),
              const SizedBox(width: Gap.md),
              Expanded(child: Text(audience == 1 ? 'member will receive this' : 'members will receive this', style: context.text.bodySmall)),
              IconButton(tooltip: 'Recalculate', onPressed: _estimate, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: 'Preview',
          subtitle: 'How it appears on a member’s lock screen',
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C1A16), Color(0xFF3A2E15)]),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: const Text(
                      'PM',
                      style: TextStyle(fontFamily: AppFonts.serif, color: AppColors.gold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('PRIVATE MEMBERS', style: TextStyle(color: Colors.white70, fontSize: 10.5, letterSpacing: 1)),
                            ),
                            Text('now', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title.text.isEmpty ? 'Your title' : title.text,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          body.text.isEmpty ? 'Your message appears here.' : body.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          onPressed: sending ? null : _send,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(sending ? 'Sending…' : 'Review & send'),
        ),
        const SizedBox(height: Gap.sm),
        Text('Every broadcast is recorded in the audit log.', textAlign: TextAlign.center, style: context.text.bodySmall),
      ],
    );

    return PageScaffold(
      scroll: true,
      maxWidth: 1200,
      title: 'Broadcast',
      subtitle: 'Send an announcement to a segment of the membership',
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: form),
                  const SizedBox(width: Gap.lg),
                  Expanded(flex: 2, child: preview),
                ],
              )
            : Column(
                children: [
                  form,
                  const SizedBox(height: Gap.lg),
                  preview,
                ],
              ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.gold.withValues(alpha: 0.10) : t.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: selected ? AppColors.gold : t.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? t.accentText : t.textMuted),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      Text(subtitle, style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 20, color: selected ? AppColors.gold : t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
