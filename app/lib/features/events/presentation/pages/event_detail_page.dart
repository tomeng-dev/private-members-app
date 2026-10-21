import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  Map<String, dynamic>? event;
  String? error;
  bool loading = true;
  bool rsvping = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      event = await ref.read(eventsRepositoryProvider).get(widget.id);
      error = null;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _rsvp(String status) async {
    if (status == 'not_going' && (event?['myRsvp']?['status'] == 'going')) {
      final ok = await showConfirmDialog(
        context,
        title: 'Cancel your RSVP?',
        message: 'Your seat may be offered to the waitlist.',
        confirmLabel: 'Cancel RSVP',
        destructive: true,
        cancelLabel: 'Keep my seat',
      );
      if (!ok) return;
    }
    setState(() => rsvping = true);
    try {
      await ref.read(eventsRepositoryProvider).rsvp(widget.id, status);
      await _load();
      if (!mounted) return;
      final my = event?['myRsvp']?['status'];
      showToast(
        context,
        my == 'going'
            ? 'You\u2019re attending — see you there'
            : my == 'waitlisted'
            ? 'You\u2019re on the waitlist'
            : 'RSVP updated',
        kind: ToastKind.success,
      );
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => rsvping = false);
    }
  }

  Widget _flexChild(bool card, Widget child) => card ? child : Expanded(child: child);

  Widget _rsvpPanel({required bool card}) {
    final e = event!;
    final my = e['myRsvp'] as Map<String, dynamic>?;
    final status = my?['status'] as String?;
    final open = e['rsvpOpen'] == true;
    final fee = e['feeUsdCents'] as int? ?? 0;
    final lux = context.lux;
    final going = e['goingCount'] ?? 0;
    final cap = e['capacity'] as int?;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card) ...[
          Text(fee > 0 ? NumberFormat.simpleCurrency(decimalDigits: 0).format(fee / 100) : 'Complimentary', style: context.text.headlineMedium),
          Text('per member', style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          if (cap != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(value: (going / cap).clamp(0.0, 1.0).toDouble(), minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$going of $cap seats taken${(e['waitlistCount'] as int? ?? 0) > 0 ? ' · ${e['waitlistCount']} waitlisted' : ''}',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
        if (status == 'going') ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: lux.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('You\u2019re attending', style: context.text.titleMedium)),
              if (my?['paymentStatus'] != null)
                StatusPill('${my!['paymentStatus']}'.toUpperCase(), color: my['paymentStatus'] == 'paid' ? lux.success : lux.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Flex(
            direction: card ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            // Stretch only vertically stacked buttons; in the bottom bar the height is unbounded.
            crossAxisAlignment: card ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            children: [
              _flexChild(card, LuxButton(label: 'My ticket', icon: Icons.qr_code_2_rounded, onPressed: () => context.push('/events/${widget.id}/ticket'))),
              if (open) ...[
                const SizedBox(width: AppSpacing.sm, height: AppSpacing.sm),
                _flexChild(card, LuxButton.secondary(label: 'Can\u2019t go', loading: rsvping, onPressed: () => _rsvp('not_going'))),
              ],
            ],
          ),
        ] else if (open)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: LuxButton(
                  label: status == 'waitlisted' ? 'On waitlist' : 'Attend',
                  icon: Icons.event_available,
                  loading: rsvping,
                  onPressed: status == 'waitlisted' ? null : () => _rsvp('going'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LuxButton.secondary(
                  label: status == 'not_going' ? 'Declined' : 'Decline',
                  onPressed: rsvping || status == 'not_going' ? null : () => _rsvp('not_going'),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(Icons.lock_clock, color: lux.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('RSVP is closed for this event', style: context.text.bodyMedium?.copyWith(color: lux.textMuted)),
              ),
            ],
          ),
        if (e['paymentLinkUrl'] != null && status == 'going' && my?['paymentStatus'] != 'paid') ...[
          const SizedBox(height: AppSpacing.sm),
          LuxButton.ghost(
            label: 'Pay event fee',
            icon: Icons.open_in_new,
            onPressed: () async {
              final uri = Uri.tryParse(e['paymentLinkUrl'] as String);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ],
    );
    if (card) return LuxCard(raised: true, padding: const EdgeInsets.all(AppSpacing.xl), child: content);
    return Container(
      decoration: BoxDecoration(
        color: lux.surfaceRaised,
        border: Border(top: BorderSide(color: lux.border)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: SafeArea(top: false, child: content),
    );
  }

  Widget _details() {
    final e = event!;
    final starts = DateTime.tryParse(e['startsAt']?.toString() ?? '')?.toLocal();
    final ends = DateTime.tryParse(e['endsAt']?.toString() ?? '')?.toLocal();
    final speakers = ((e['speakers'] as List?) ?? []).cast<Map<String, dynamic>>();
    final lux = context.lux;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e['title']?.toString() ?? '', style: context.text.displaySmall),
        const SizedBox(height: AppSpacing.lg),
        if (starts != null)
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            title: DateFormat.yMMMMEEEEd().format(starts),
            subtitle: '${DateFormat.jm().format(starts)}${ends != null ? ' – ${DateFormat.jm().format(ends)}' : ''} · ${e['timezone'] ?? ''}',
          ),
        if ((e['venueName'] ?? '').toString().isNotEmpty)
          _InfoRow(
            icon: Icons.place_outlined,
            title: e['venueName'].toString(),
            subtitle: (e['venueAddress']?.toString() ?? '').trim().isEmpty || e['venueAddress'] == e['venueName'] ? null : e['venueAddress'].toString(),
          ),
        _InfoRow(
          icon: Icons.people_alt_outlined,
          title: '${e['goingCount'] ?? 0} members attending',
          subtitle: e['spotsLeft'] != null ? '${e['spotsLeft']} seats left' : null,
          onTap: () => context.push('/events/${widget.id}/attendees'),
        ),
        if ((e['description'] ?? '').toString().isNotEmpty) ...[const SectionHeader('About'), Text(e['description'].toString(), style: context.text.bodyLarge)],
        if (speakers.isNotEmpty) ...[
          const SectionHeader('Speakers & hosts'),
          for (final s in speakers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: LuxCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MemberAvatar(name: s['name']?.toString() ?? '?', size: 52),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(s['name']?.toString() ?? '', style: context.text.titleMedium)),
                              const SizedBox(width: AppSpacing.sm),
                              StatusPill('${s['role']}'.toUpperCase()),
                            ],
                          ),
                          if ((s['topic'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(s['topic'].toString(), style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                          ],
                          for (final k in ['hostName', 'menuNotes', 'bio'])
                            if ((s[k] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xs),
                                child: Text(s[k].toString(), style: context.text.bodySmall),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SectionHeader('Members'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ActionChip(
              avatar: Icon(Icons.forum_outlined, size: 18, color: lux.accentText),
              label: const Text('Discussion thread'),
              onPressed: () => context.push('/events/${widget.id}/thread'),
            ),
            ActionChip(
              avatar: Icon(Icons.people_outline, size: 18, color: lux.accentText),
              label: const Text('Who\u2019s attending'),
              onPressed: () => context.push('/events/${widget.id}/attendees'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/home?tab=events', color: AppColors.white),
        ),
        body: const SkeletonList(count: 2, media: true),
      );
    }
    if (event == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/home?tab=events', color: AppColors.white),
        ),
        body: ErrorState(message: error ?? 'Event not found', onRetry: _load),
      );
    }
    final wide = context.screenWidth >= 1000;
    final cover = SliverAppBar(
      leading: const AppBackButton(fallback: '/home?tab=events', color: AppColors.white),
      pinned: true,
      expandedHeight: wide ? 300 : 240,
      backgroundColor: context.lux.surfaceSunken,
      foregroundColor: AppColors.white,
      iconTheme: const IconThemeData(color: AppColors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'event-cover-${widget.id}',
          child: CoverArt(
            seed: widget.id,
            height: 300,
            child: Positioned(
              left: AppSpacing.xl,
              bottom: AppSpacing.xl,
              child: DateTime.tryParse(event!['startsAt']?.toString() ?? '') == null
                  ? const SizedBox.shrink()
                  : DateBadge(date: DateTime.parse(event!['startsAt'].toString()), size: 68),
            ),
          ),
        ),
      ),
    );
    final body = RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          cover,
          SliverToBoxAdapter(
            child: CenteredContent(
              child: Padding(
                padding: pagePadding(context, top: AppSpacing.xl),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _details()),
                          const SizedBox(width: AppSpacing.xxl),
                          SizedBox(width: 340, child: _rsvpPanel(card: true)),
                        ],
                      )
                    : _details(),
              ),
            ),
          ),
        ],
      ),
    );
    return Scaffold(body: body, bottomNavigationBar: wide ? null : _rsvpPanel(card: false));
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Icon(icon, color: context.lux.accentText, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
