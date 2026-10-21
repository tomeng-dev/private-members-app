import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/post.dart';
import '../widgets/post_card.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.id, this.post});
  final String id;
  final FeedPost? post;
  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  List<FeedComment> comments = [];
  final commentCtrl = TextEditingController();
  late FeedPost? post = widget.post;
  String? error;
  bool loading = true;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    commentCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      comments = await ref.read(feedRepositoryProvider).comments(widget.id);
      error = null;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final text = commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => sending = true);
    try {
      await ref.read(feedRepositoryProvider).addComment(widget.id, text);
      commentCtrl.clear();
      if (post != null) post = post!.copyWith(commentCount: post!.commentCount + 1);
      await _load();
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _report() async {
    final reason = await showInputDialog(context, title: 'Report post', label: 'Reason');
    if (reason == null || reason.isEmpty) return;
    await ref.read(feedRepositoryProvider).report(targetType: 'post', targetId: widget.id, reason: reason);
    if (mounted) showToast(context, 'Report submitted', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home'),
        title: const Text('Post'),
        actions: [IconButton(tooltip: 'Report post', onPressed: _report, icon: const Icon(Icons.flag_outlined))],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CenteredContent(
                maxWidth: AppBreakpoints.feedMaxWidth + 48,
                child: ListView(
                  padding: pagePadding(context),
                  children: [
                    if (post != null) PostCard(post: post!, expanded: true),
                    SectionHeader('Comments', subtitle: loading ? null : '${comments.length} ${comments.length == 1 ? 'reply' : 'replies'}'),
                    if (loading)
                      const SkeletonCard(lines: 2)
                    else if (error != null)
                      ErrorState(message: error!, onRetry: _load)
                    else if (comments.isEmpty)
                      const EmptyState(icon: Icons.mode_comment_outlined, title: 'No comments yet', message: 'Start the conversation.')
                    else
                      for (final c in comments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MemberAvatar(name: c.authorName, size: 36, founding: c.authorFounding),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: lux.surface,
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                    border: Border.all(color: lux.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(c.authorName, style: context.text.titleSmall)),
                                          if (c.createdAt != null) Text(relativeTime(c.createdAt!), style: context.text.bodySmall),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(c.body, style: context.text.bodyMedium),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: lux.surface,
              border: Border(top: BorderSide(color: lux.border)),
            ),
            child: SafeArea(
              top: false,
              child: CenteredContent(
                maxWidth: AppBreakpoints.feedMaxWidth + 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(hintText: 'Write a comment…'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filled(
                        tooltip: 'Send comment',
                        onPressed: commentCtrl.text.trim().isEmpty || sending ? null : _send,
                        style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.black),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
