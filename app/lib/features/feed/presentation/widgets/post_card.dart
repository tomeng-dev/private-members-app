import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/post.dart';

/// Feed post card: author header, body, link preview, shared quote, actions.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap, this.onLike, this.onComment, this.onShare, this.onAuthorTap, this.onMore, this.expanded = false});

  final FeedPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onMore;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    final p = post;
    return LuxCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticsLabel: 'Post by ${p.authorName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.xs, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: onAuthorTap,
                  customBorder: const CircleBorder(),
                  child: MemberAvatar(name: p.authorName, founding: p.authorFounding),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(p.authorName, style: context.text.titleMedium, overflow: TextOverflow.ellipsis),
                          ),
                          if (p.authorFounding) ...[const SizedBox(width: AppSpacing.sm), const FoundingBadge(compact: true)],
                        ],
                      ),
                      Text(
                        [if ((p.authorSubtitle ?? '').isNotEmpty) p.authorSubtitle!, relativeTime(p.createdAt)].join(' · '),
                        style: context.text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onMore != null) IconButton(tooltip: 'More options', onPressed: onMore, icon: const Icon(Icons.more_horiz)),
              ],
            ),
          ),
          if ((p.body ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Text(p.body!, style: context.text.bodyLarge, maxLines: expanded ? null : 8, overflow: expanded ? null : TextOverflow.ellipsis),
            ),
          if (p.linkUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: lux.border),
                  color: lux.surfaceSunken,
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      color: AppColors.gold.withValues(alpha: 0.12),
                      child: Icon(Icons.link_rounded, color: lux.accentText),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.linkTitle ?? p.linkUrl!, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(Uri.tryParse(p.linkUrl!)?.host ?? p.linkUrl!, style: context.text.bodySmall, maxLines: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ),
            ),
          if (p.sharedFromBody != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.gold.withValues(alpha: 0.7), width: 3)),
                  color: lux.surfaceSunken,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(AppRadii.sm), bottomRight: Radius.circular(AppRadii.sm)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.sharedFromAuthor ?? 'Member', style: context.text.labelMedium?.copyWith(color: lux.accentText)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(p.sharedFromBody!, style: context.text.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                _Action(
                  icon: p.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '${p.likeCount}',
                  semantics: p.likedByMe ? 'Unlike, ${p.likeCount} likes' : 'Like, ${p.likeCount} likes',
                  active: p.likedByMe,
                  onTap: onLike,
                ),
                _Action(icon: Icons.mode_comment_outlined, label: '${p.commentCount}', semantics: 'Comments, ${p.commentCount}', onTap: onComment),
                _Action(icon: Icons.ios_share_rounded, label: 'Share', semantics: 'Share post', onTap: onShare),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.semantics, this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = active ? context.lux.accentText : context.lux.textMuted;
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: c,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          icon: AnimatedSwitcher(
            duration: AppMotion.fast,
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: Icon(icon, key: ValueKey(icon), size: 22),
          ),
          label: Text(label, style: context.text.labelMedium?.copyWith(color: c)),
        ),
      ),
    );
  }
}

/// "Share something…" prompt opening the composer.
class ComposerPrompt extends StatelessWidget {
  const ComposerPrompt({super.key, required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return LuxCard(
      onTap: onTap,
      semanticsLabel: 'Create a post',
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          MemberAvatar(name: name, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.lux.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: context.lux.border),
              ),
              child: Text(
                'Share with members…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(color: context.lux.textMuted),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.edit_outlined, color: context.lux.accentText),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
