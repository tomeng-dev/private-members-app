import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class EventAttendeesPage extends ConsumerStatefulWidget {
  const EventAttendeesPage({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<EventAttendeesPage> createState() => _EventAttendeesPageState();
}

class _EventAttendeesPageState extends ConsumerState<EventAttendeesPage> {
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
      items = await ref.read(eventsRepositoryProvider).attendees(widget.eventId);
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=events'),
        title: const Text('Attendees'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : error != null
          ? Center(
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final a = items[i];
                return ListTile(
                  title: Text('${a['firstName']} ${a['lastName']}', style: const TextStyle(fontSize: 17)),
                  subtitle: Text(a['company'] as String? ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  onTap: () => context.push('/members/${a['userId']}'),
                );
              },
            ),
    );
  }
}
