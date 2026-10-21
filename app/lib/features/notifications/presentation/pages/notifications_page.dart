import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      items = await ref.read(notificationsRepositoryProvider).list();
      error = null;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> n) {
    try {
      return n['dataJson'] == null ? {} : Map<String, dynamic>.from(jsonDecode(n['dataJson'] as String) as Map);
    } catch (_) {
      return {};
    }
  }

  IconData _icon(String type) {
    if (type.contains('event')) return Icons.event_outlined;
    if (type.contains('message')) return Icons.chat_bubble_outline;
    if (type.contains('dues')) return Icons.receipt_long_outlined;
    if (type.contains('moderation')) return Icons.shield_outlined;
    if (type.contains('broadcast')) return Icons.campaign_outlined;
    if (type.contains('comment')) return Icons.mode_comment_outlined;
    if (type.contains('like')) return Icons.favorite_border_rounded;
    return Icons.notifications_none_rounded;
  }

  Future<void> _open(Map<String, dynamic> n) async {
    if (n['readAt'] == null) {
      await ref.read(notificationsRepositoryProvider).markRead(n['id'] as String);
      setState(() => n['readAt'] = DateTime.now().toIso8601String());
    }
    final d = _data(n);
    final type = '${d['type'] ?? ''}';
    if (!mounted) return;
    if (type.contains('event') && d['eventId'] != null) {
      context.push('/events/${d['eventId']}');
    } else if (type.contains('message') && d['conversationId'] != null) {
      context.push('/messages/${d['conversationId']}');
    } else if (d['postId'] != null) {
      context.push('/posts/${d['postId']}');
    }
  }

  String _bucket(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inHours < 24) return 'Today';
    if (d.inDays < 7) return 'This week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final unread = items.where((n) => n['readAt'] == null).length;
    final rows = <Widget>[];
    String? last;
    for (final n in items) {
      final t = DateTime.tryParse('${n['createdAt']}')?.toLocal() ?? DateTime.now();
      final b = _bucket(t);
      if (b != last) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.lg, 0, AppSpacing.sm),
            child: Text(b.toUpperCase(), style: context.text.labelSmall?.copyWith(color: context.lux.textMuted)),
          ),
        );
        last = b;
      }
      final isUnread = n['readAt'] == null;
      final type = '${_data(n)['type'] ?? ''}';
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: LuxCard(
            onTap: () => _open(n),
            raised: isUnread,
            semanticsLabel: '${isUnread ? 'Unread. ' : ''}${n['title']}. ${n['body']}',
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: isUnread ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(_icon(type), color: context.lux.accentText),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${n['title']}', style: context.text.titleSmall?.copyWith(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(relativeTime(t), style: context.text.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${n['body']}', style: context.text.bodyMedium?.copyWith(color: context.lux.textMuted)),
                    ],
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home'),
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () async {
                await ref.read(notificationsRepositoryProvider).markAllRead();
                await _load();
                if (context.mounted) showToast(context, 'All caught up', kind: ToastKind.success);
              },
            ),
          IconButton(tooltip: 'Notification settings', onPressed: () => context.push('/settings/notifications'), icon: const Icon(Icons.tune)),
        ],
      ),
      body: loading
          ? const SkeletonList(count: 5)
          : error != null
          ? ErrorState(message: error!, onRetry: _load)
          : items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'You\u2019re all caught up',
              message: 'Event updates, messages and club notices will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CenteredContent(
                maxWidth: 760,
                child: ListView(padding: pagePadding(context, top: 0), children: rows),
              ),
            ),
    );
  }
}
