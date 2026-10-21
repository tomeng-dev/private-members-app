import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class NotificationPrefsPage extends ConsumerStatefulWidget {
  const NotificationPrefsPage({super.key});
  @override
  ConsumerState<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends ConsumerState<NotificationPrefsPage> {
  Map<String, dynamic>? prefs;
  bool loading = true;
  String? error;

  static const keys = [
    ('pushMessages', 'Push: messages'),
    ('pushEvents', 'Push: events'),
    ('pushThreads', 'Push: threads'),
    ('pushDues', 'Push: dues'),
    ('pushApplications', 'Push: applications'),
    ('emailEvents', 'Email: events'),
    ('emailDues', 'Email: dues'),
    ('emailApplications', 'Email: applications'),
  ];

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
      prefs = await ref.read(notificationsRepositoryProvider).getPrefs();
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    try {
      prefs = await ref.read(notificationsRepositoryProvider).updatePrefs({key: value});
      setState(() {});
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/notifications'),
        title: const Text('Notification preferences'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose which alerts you receive. Defaults are on.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                ),
                if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                for (final (k, label) in keys)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(label, style: const TextStyle(fontSize: 17)),
                    value: prefs?[k] != false,
                    activeThumbColor: AppColors.black,
                    activeTrackColor: AppColors.gold,
                    onChanged: (v) => _toggle(k, v),
                  ),
              ],
            ),
    );
  }
}
