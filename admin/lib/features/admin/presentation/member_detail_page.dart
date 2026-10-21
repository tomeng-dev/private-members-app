import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/ui.dart';
import 'member_drawer.dart';

/// Full-page member view (same content as the members table drawer).
class MemberDetailPage extends StatelessWidget {
  const MemberDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      maxWidth: 1000,
      title: 'Member',
      actions: [
        TextButton.icon(onPressed: () => context.go('/members'), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: const Text('All members')),
      ],
      child: MemberDetailDrawer(memberId: id, asPage: true),
    );
  }
}
