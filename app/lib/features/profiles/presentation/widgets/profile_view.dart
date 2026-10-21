import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/member_profile.dart';

/// Shared profile layout: cover + avatar, identity, actions, vehicles gallery, business.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.profile, required this.actions, this.extra = const []});
  final MemberProfile profile;
  final List<Widget> actions;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final name = '${p.firstName} ${p.lastName}'.trim();
    final lux = context.lux;
    final location = [p.city, p.state].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(bottom: 56, child: CoverArt(seed: p.id, height: 164)),
              Positioned(
                left: context.isCompact ? AppSpacing.lg : AppSpacing.xl,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4),
                  ),
                  child: MemberAvatar(name: name, size: 108, founding: p.foundingMember, heroTag: 'avatar-${p.id}'),
                ),
              ),
            ],
          ),
        ),
        CenteredContent(
          maxWidth: 880,
          child: Padding(
            padding: pagePadding(context, top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(name, style: context.text.displaySmall),
                    if (p.foundingMember) const FoundingBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if ((p.title ?? '').isNotEmpty || (p.company ?? '').isNotEmpty)
                  Text(
                    [p.title, p.company].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: context.text.titleMedium?.copyWith(color: lux.textMuted, fontWeight: FontWeight.w500),
                  ),
                if (location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: lux.textMuted),
                        const SizedBox(width: 4),
                        Text(location, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                if ((p.bio ?? '').isNotEmpty) ...[const SizedBox(height: AppSpacing.lg), Text(p.bio!, style: context.text.bodyLarge)],
                const SizedBox(height: AppSpacing.lg),
                _ProfileActions(actions: actions),
                SectionHeader('Garage', subtitle: '${p.vehicles.length} vehicle${p.vehicles.length == 1 ? '' : 's'}'),
                if (p.vehicles.isEmpty)
                  Text('No vehicles listed yet.', style: context.text.bodySmall)
                else
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: p.vehicles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, i) => _VehicleTile(v: p.vehicles[i]),
                    ),
                  ),
                if (p.businessPage != null) ...[const SectionHeader('Business'), _BusinessCard(b: p.businessPage!)],
                if ((p.showEmail && p.email != null) || (p.showPhone && p.phone != null)) ...[
                  const SectionHeader('Contact'),
                  LuxCard(
                    child: Column(
                      children: [
                        if (p.email != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.mail_outline), title: Text(p.email!)),
                        if (p.phone != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(p.phone!)),
                      ],
                    ),
                  ),
                ],
                ...extra,
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.v});
  final VehicleItem v;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: LuxCard(
        padding: EdgeInsets.zero,
        semanticsLabel: '${v.year} ${v.make} ${v.model}${v.isPrimary ? ', primary vehicle' : ''}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
              seed: '${v.make}${v.model}',
              height: 110,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
              child: v.isPrimary
                  ? const Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: StatusPill('PRIMARY', color: AppColors.champagne),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${v.make} ${v.model}', style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text([v.year > 0 ? '${v.year}' : null, v.color].whereType<String>().join(' · '), style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.b});
  final BusinessPageItem b;
  @override
  Widget build(BuildContext context) {
    return LuxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Icon(Icons.business_center_outlined, color: context.lux.accentText),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(b.companyName, style: context.text.titleMedium)),
            ],
          ),
          if ((b.services ?? '').isNotEmpty) ...[const SizedBox(height: AppSpacing.md), Text(b.services!, style: context.text.bodyMedium)],
          if ((b.background ?? '').isNotEmpty) ...[const SizedBox(height: AppSpacing.sm), Text(b.background!, style: context.text.bodySmall)],
          if ((b.website ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () async {
                final u = Uri.tryParse(b.website!);
                if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(Uri.tryParse(b.website!)?.host ?? b.website!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays out profile actions: on phones the primary action spans the width and
/// secondary actions share a row; on wider screens they sit inline.
class _ProfileActions extends StatelessWidget {
  const _ProfileActions({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    if (context.screenWidth >= AppBreakpoints.compact || actions.length == 1) {
      return Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions);
    }
    final rest = actions.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actions.first,
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < rest.length; i++) ...[if (i > 0) const SizedBox(width: AppSpacing.sm), Expanded(child: rest[i])],
          ],
        ),
      ],
    );
  }
}
