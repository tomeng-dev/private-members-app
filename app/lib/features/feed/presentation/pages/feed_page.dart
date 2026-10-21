import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/post.dart';
import '../widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});
  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final items = <FeedPost>[];
  String? cursor;
  bool loading = true;
  bool loadingMore = false;
  String? error;
  String myName = '';
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
    ref
        .read(profilesRepositoryProvider)
        .myProfile()
        .then((p) {
          if (mounted) setState(() => myName = '${p.firstName} ${p.lastName}');
        })
        .catchError((_) {});
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 400 && cursor != null && !loadingMore) _loadMore();
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => error = null);
    try {
      final page = await ref.read(feedRepositoryProvider).feed();
      items
        ..clear()
        ..addAll(page.items);
      cursor = page.nextCursor;
    } on Failure catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not load the feed.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (cursor == null) return;
    setState(() => loadingMore = true);
    try {
      final page = await ref.read(feedRepositoryProvider).feed(cursor: cursor);
      items.addAll(page.items);
      cursor = page.items.isEmpty ? null : page.nextCursor;
    } catch (_) {
      cursor = null;
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> _like(FeedPost post) async {
    // optimistic
    final i = items.indexWhere((p) => p.id == post.id);
    if (i < 0) return;
    final liked = !post.likedByMe;
    setState(() => items[i] = post.copyWith(likedByMe: liked, likeCount: (post.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 30)));
    try {
      final server = await ref.read(feedRepositoryProvider).toggleLike(post.id);
      if (server != liked && mounted) setState(() => items[i] = post);
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() => items[i] = post);
      showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _share(FeedPost p) async {
    final ok = await showConfirmDialog(context, title: 'Share to your feed?', message: 'Members will see this post shared by you.', confirmLabel: 'Share');
    if (!ok) return;
    try {
      await ref.read(feedRepositoryProvider).createPost(body: 'Shared a post', sharedFromPostId: p.id);
      if (mounted) showToast(context, 'Shared to your feed', kind: ToastKind.success);
      await _refresh();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _more(FeedPost p) async {
    final action = await showLuxSheet<String>(
      context,
      title: 'Post options',
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.authorId != null)
              ListTile(leading: const Icon(Icons.person_outline), title: const Text('View profile'), onTap: () => Navigator.pop(ctx, 'profile')),
            if (p.isOwner)
              ListTile(
                leading: Icon(Icons.delete_outline, color: ctx.lux.danger),
                title: Text('Delete post', style: TextStyle(color: ctx.lux.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report post'), onTap: () => Navigator.pop(ctx, 'report')),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') context.push('/members/${p.authorId}');
    if (action == 'delete') {
      final ok = await showConfirmDialog(context, title: 'Delete post?', message: 'This cannot be undone.', confirmLabel: 'Delete', destructive: true);
      if (!ok || !mounted) return;
      await ref.read(feedRepositoryProvider).deletePost(p.id);
      if (mounted) showToast(context, 'Post deleted', kind: ToastKind.success);
      await _refresh();
    }
    if (action == 'report') {
      if (!mounted) return;
      final reason = await showInputDialog(context, title: 'Report post', label: 'Reason');
      if (reason == null || reason.isEmpty) return;
      await ref.read(feedRepositoryProvider).report(targetType: 'post', targetId: p.id, reason: reason);
      if (mounted) showToast(context, 'Thanks — our moderators will review it', kind: ToastKind.success);
    }
  }

  Future<void> _compose() async {
    await context.push('/compose');
    await _refresh();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Good morning'
        : h < 18
        ? 'Good afternoon'
        : 'Good evening';
    final first = myName.split(' ').first;
    return first.isEmpty ? part : '$part, $first';
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    Widget content;
    if (loading) {
      content = SkeletonList(count: 3, padding: pad);
    } else if (error != null && items.isEmpty) {
      content = ListView(
        children: [
          const SizedBox(height: 80),
          ErrorState(message: error!, onRetry: _refresh),
        ],
      );
    } else {
      content = ListView.separated(
        controller: scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pad,
        itemCount: items.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: context.text.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('What members are sharing today', style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                ComposerPrompt(name: myName.isEmpty ? 'Me' : myName, onTap: _compose),
              ],
            );
          }
          if (i == items.length + 1) {
            if (loadingMore) return const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: SkeletonCard());
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: EmptyState(icon: Icons.forum_outlined, title: 'The feed is quiet', message: 'Be the first to share a drive, a find, or a thought.'),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text(cursor == null ? 'You\u2019re all caught up' : '', style: context.text.bodySmall)),
            );
          }
          final p = items[i - 1];
          return PostCard(
            post: p,
            onTap: () => context.push('/posts/${p.id}', extra: p),
            onComment: () => context.push('/posts/${p.id}', extra: p),
            onLike: () => _like(p),
            onShare: () => _share(p),
            onMore: () => _more(p),
            onAuthorTap: p.authorId == null ? null : () => context.push('/members/${p.authorId}'),
          );
        },
      );
    }
    final feed = RefreshIndicator(
      onRefresh: _refresh,
      child: CenteredContent(maxWidth: AppBreakpoints.feedMaxWidth + 48, child: content),
    );
    // Large desktop: feed + "Coming up" side rail, so the wide canvas isn't empty.
    if (context.screenWidth < 1280) return feed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: feed),
        const SizedBox(width: 320, child: _UpcomingRail()),
        const SizedBox(width: AppSpacing.xl),
      ],
    );
  }
}

class _UpcomingRail extends ConsumerStatefulWidget {
  const _UpcomingRail();
  @override
  ConsumerState<_UpcomingRail> createState() => _UpcomingRailState();
}

class _UpcomingRailState extends ConsumerState<_UpcomingRail> {
  late final Future<List<Map<String, dynamic>>> _events = ref.read(eventsRepositoryProvider).list();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xl),
      children: [
        LuxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Coming up', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _events,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Column(
                      children: [
                        Skeleton(height: 48),
                        SizedBox(height: AppSpacing.sm),
                        Skeleton(height: 48),
                      ],
                    );
                  }
                  final items = (snap.data ?? const []).take(3).toList();
                  if (items.isEmpty) return Text('No upcoming events yet.', style: context.text.bodySmall);
                  return Column(
                    children: [
                      for (final e in items)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          onTap: () => context.push('/events/${e['id']}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                if (DateTime.tryParse('${e['startsAt']}') case final d?) DateBadge(date: d.toLocal()),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${e['title']}', style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      if ((e['venueName'] ?? '').toString().isNotEmpty)
                                        Text('${e['venueName']}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              LuxButton.ghost(label: 'All events', icon: Icons.arrow_forward_rounded, onPressed: () => context.go('/home?tab=events')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LuxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Club etiquette', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Everything shared here stays within the membership. Please ask before posting photos of other members or their vehicles.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
