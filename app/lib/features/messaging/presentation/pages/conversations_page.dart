import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/conversation.dart';

class ConversationsPage extends ConsumerStatefulWidget {
  const ConversationsPage({super.key});
  @override
  ConsumerState<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends ConsumerState<ConversationsPage> {
  List<ConversationSummary> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(socketServiceProvider).connect();
  }

  Future<void> _load() async {
    try {
      items = await ref.read(messagingRepositoryProvider).conversations();
      error = null;
    } on Failure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Could not load messages.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    Widget body;
    if (loading) {
      body = ListView.separated(
        padding: pad,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (_, __) => const Row(
          children: [
            Skeleton(width: 52, height: 52, circle: true),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(width: 160), SizedBox(height: 8), Skeleton()]),
            ),
          ],
        ),
      );
    } else if (error != null) {
      body = ErrorState(message: error!, onRetry: _load);
    } else if (items.isEmpty) {
      body = ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No conversations yet',
            message: 'Start a private conversation from any member\u2019s profile.',
            actionLabel: 'Browse members',
            onAction: () => context.go('/home?tab=members'),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        padding: pad,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final c = items[i];
          final unread = c.unreadCount > 0;
          return Semantics(
            button: true,
            label: '${c.participantName}${unread ? ', ${c.unreadCount} unread' : ''}. ${c.lastBody ?? ''}',
            child: ExcludeSemantics(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () async {
                    await context.push('/messages/${c.id}?name=${Uri.encodeComponent(c.participantName)}&peer=${c.participantId}');
                    _load();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        MemberAvatar(name: c.participantName, size: 52, founding: c.participantFounding),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.participantName,
                                      style: context.text.titleMedium?.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (c.lastAt != null)
                                    Text(relativeTime(c.lastAt!), style: context.text.bodySmall?.copyWith(color: unread ? context.lux.accentText : null)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.lastBody ?? 'No messages yet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.bodyMedium?.copyWith(color: unread ? context.lux.textPrimary : context.lux.textMuted),
                                    ),
                                  ),
                                  if (unread)
                                    Container(
                                      margin: const EdgeInsets.only(left: AppSpacing.sm),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(AppRadii.pill)),
                                      child: Text(
                                        '${c.unreadCount}',
                                        style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CenteredContent(maxWidth: 760, child: body),
    );
  }
}
