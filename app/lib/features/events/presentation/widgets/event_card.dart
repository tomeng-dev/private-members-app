import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/ui.dart';

/// Event card: generated cover with date badge, serif title, venue/time meta.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap, this.compact = false});
  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final id = event['id']?.toString() ?? '';
    final title = event['title']?.toString() ?? 'Event';
    final starts = DateTime.tryParse(event['startsAt']?.toString() ?? '')?.toLocal();
    final venue = event['venueName']?.toString();
    final going = (event['_count'] as Map?)?['rsvps'] ?? event['goingCount'];
    final cap = event['capacity'];
    final fee = event['feeUsdCents'] as int?;
    final lux = context.lux;
    return LuxCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticsLabel: '$title${starts != null ? ', ${DateFormat.yMMMMEEEEd().add_jm().format(starts)}' : ''}${venue != null ? ', $venue' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'event-cover-$id',
            child: CoverArt(
              seed: id,
              height: compact ? 110 : 150,
              child: Stack(
                children: [
                  if (starts != null)
                    Positioned(
                      left: AppSpacing.md,
                      top: AppSpacing.md,
                      child: DateBadge(date: starts),
                    ),
                  if (fee != null && fee > 0)
                    Positioned(
                      right: AppSpacing.md,
                      top: AppSpacing.md,
                      child: StatusPill(NumberFormat.simpleCurrency(decimalDigits: 0).format(fee / 100), color: AppColors.champagne),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.sm),
                if (starts != null) _Meta(icon: Icons.schedule_rounded, text: '${DateFormat.EEEE().format(starts)} · ${DateFormat.jm().format(starts)}'),
                if (venue != null && venue.isNotEmpty) _Meta(icon: Icons.place_outlined, text: venue),
                if (going != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined, size: 16, color: lux.accentText),
                      const SizedBox(width: AppSpacing.xs),
                      Text(cap != null ? '$going / $cap attending' : '$going attending', style: context.text.labelMedium?.copyWith(color: lux.accentText)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xxs),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.lux.textMuted),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(text, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}
