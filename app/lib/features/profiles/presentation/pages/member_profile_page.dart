import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/member_profile.dart';
import '../widgets/profile_view.dart';

class MemberProfilePage extends ConsumerStatefulWidget {
  const MemberProfilePage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends ConsumerState<MemberProfilePage> {
  MemberProfile? profile;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      profile = await ref.read(profilesRepositoryProvider).getMember(widget.id);
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _message() async {
    try {
      final id = await ref.read(messagingRepositoryProvider).startConversation(widget.id);
      if (!mounted) return;
      final name = '${profile!.firstName} ${profile!.lastName}'.trim();
      context.push('/messages/$id?name=${Uri.encodeComponent(name)}&peer=${widget.id}');
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _report() async {
    final reason = await showInputDialog(context, title: 'Report member', label: 'What happened?');
    if (reason == null || reason.isEmpty) return;
    try {
      await ref.read(feedRepositoryProvider).report(targetType: 'user', targetId: widget.id, reason: reason);
      if (mounted) showToast(context, 'Report sent to moderators', kind: ToastKind.success);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _block() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Block this member?',
      message: 'They will no longer be able to message you.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(messagingRepositoryProvider).block(widget.id);
      if (mounted) showToast(context, 'Member blocked', kind: ToastKind.success);
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=members', color: AppColors.white),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            onSelected: (v) => v == 'report' ? _report() : _block(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report member')),
              PopupMenuItem(value: 'block', child: Text('Block member')),
            ],
          ),
        ],
      ),
      body: loading
          ? const SkeletonList(count: 2, media: true)
          : profile == null
          ? ErrorState(message: error ?? 'Member not found', onRetry: _load)
          : ProfileView(
              profile: profile!,
              actions: [LuxButton(label: 'Message', icon: Icons.chat_bubble_outline, onPressed: _message)],
            ),
    );
  }
}
