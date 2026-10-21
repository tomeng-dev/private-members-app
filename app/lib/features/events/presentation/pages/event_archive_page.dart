import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class EventArchivePage extends ConsumerStatefulWidget {
  const EventArchivePage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EventArchivePage> createState() => _EventArchivePageState();
}

class _EventArchivePageState extends ConsumerState<EventArchivePage> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      data = await ref.read(eventsRepositoryProvider).archive(widget.id);
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = data?['event'] as Map<String, dynamic>?;
    final attendees = ((data?['attendees']?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    final thread = ((data?['thread']?['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=events'),
        title: const Text('Event archive'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : error != null
          ? Center(
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(event?['title'] as String? ?? '', style: Theme.of(context).textTheme.headlineMedium),
                Text(event?['description'] as String? ?? '', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Text('Attendees (${attendees.length})', style: Theme.of(context).textTheme.titleLarge),
                for (final a in attendees)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${a['firstName']} ${a['lastName']}', style: const TextStyle(fontSize: 17)),
                    subtitle: Text(a['company'] as String? ?? ''),
                    onTap: () => context.push('/members/${a['userId']}'),
                  ),
                const SizedBox(height: 16),
                Text('Thread history', style: Theme.of(context).textTheme.titleLarge),
                for (final c in thread)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c['body'] as String? ?? '', style: const TextStyle(fontSize: 16)),
                  ),
                TextButton(onPressed: () => context.push('/events/${widget.id}/thread'), child: const Text('Open live thread')),
              ],
            ),
    );
  }
}
