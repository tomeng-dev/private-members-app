import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';

class InvitesPage extends ConsumerStatefulWidget {
  const InvitesPage({super.key});
  @override
  ConsumerState<InvitesPage> createState() => _InvitesPageState();
}

class _InvitesPageState extends ConsumerState<InvitesPage> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      items = await ref.read(adminRepositoryProvider).listInvites();
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final code = TextEditingController();
    final uses = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Code (optional)'),
            ),
            TextField(
              controller: uses,
              decoration: const InputDecoration(labelText: 'Max uses'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).createInvite({
        if (code.text.trim().isNotEmpty) 'code': code.text.trim(),
        'maxUses': int.tryParse(uses.text) ?? 1,
      });
      await _load();
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(child: Text('Invite codes', style: Theme.of(context).textTheme.headlineMedium)),
            ElevatedButton(onPressed: _create, child: const Text('New invite')),
          ],
        ),
        if (error != null) Text(error!, style: const TextStyle(color: AppColors.error)),
        const SizedBox(height: 16),
        if (items.isEmpty) const Text('No invites yet', style: TextStyle(color: AppColors.muted, fontSize: 17)),
        for (final raw in items)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            title: Text((raw as Map)['code']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text('Uses ${(raw)['usesCount'] ?? 0}/${(raw)['maxUses'] ?? 1} · ${(raw)['status']}', style: const TextStyle(color: AppColors.muted)),
            trailing: (raw)['status'] == 'active'
                ? TextButton(
                    onPressed: () async {
                      await ref.read(adminRepositoryProvider).revokeInvite(raw['id'] as String);
                      await _load();
                    },
                    child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
                  )
                : null,
          ),
      ],
    );
  }
}
