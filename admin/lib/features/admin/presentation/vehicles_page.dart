import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';

class VehiclesVerificationPage extends ConsumerStatefulWidget {
  const VehiclesVerificationPage({super.key});
  @override
  ConsumerState<VehiclesVerificationPage> createState() => _VehiclesVerificationPageState();
}

class _VehiclesVerificationPageState extends ConsumerState<VehiclesVerificationPage> {
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
      items = await ref.read(adminRepositoryProvider).vehicleVerifications();
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _review(String id, String decision) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(decision == 'approved' ? 'Approve vehicle' : 'Reject vehicle'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
          minLines: 2,
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).reviewVehicle(id, decision, note: note.text.trim().isEmpty ? null : note.text.trim());
      await _load();
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _openProof(String mediaId) async {
    try {
      final proof = await ref.read(adminRepositoryProvider).vehicleProofUrl(mediaId);
      final url = proof['url'] as String?;
      if (url == null) return;
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Vehicle verification', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Review submitted ownership proofs. Documents auto-delete 30 days after decision.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: AppColors.error))],
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Queue is empty',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 17),
              ),
            ),
          for (final raw in items)
            Builder(
              builder: (_) {
                final v = raw as Map<String, dynamic>;
                final user = v['user'] as Map<String, dynamic>? ?? {};
                final media = (v['media'] as List?) ?? [];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${v['year']} ${v['make']} ${v['model']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text('${user['firstName']} ${user['lastName']} · ${user['email']}', style: const TextStyle(color: AppColors.muted)),
                        Text('Status: ${v['verificationStatus']}', style: const TextStyle(color: AppColors.gold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final m in media)
                              OutlinedButton.icon(
                                onPressed: () => _openProof(m['id'] as String),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('View proof'),
                              ),
                            ElevatedButton(onPressed: () => _review(v['id'] as String, 'approved'), child: const Text('Approve')),
                            OutlinedButton(onPressed: () => _review(v['id'] as String, 'rejected'), child: const Text('Reject')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
