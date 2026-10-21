import '../../../../core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';

class EventThreadPage extends ConsumerStatefulWidget {
  const EventThreadPage({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<EventThreadPage> createState() => _EventThreadPageState();
}

class _EventThreadPageState extends ConsumerState<EventThreadPage> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> items = [];
  String? threadId;
  String? error;
  bool loading = true;

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
      final t = await ref.read(eventsRepositoryProvider).thread(widget.eventId);
      threadId = t.threadId;
      items = t.items;
      final sock = ref.read(socketServiceProvider);
      await sock.connect();
      if (threadId != null) sock.joinThread(threadId!);
      sock.on('thread:comment', _onComment);
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onComment(dynamic data) {
    if (data is! Map) return;
    final comment = data['comment'];
    if (comment is Map<String, dynamic>) {
      setState(() => items = [...items, comment]);
    }
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    _ctrl.clear();
    try {
      await ref.read(eventsRepositoryProvider).comment(widget.eventId, body);
      await _load();
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  void dispose() {
    ref.read(socketServiceProvider).off('thread:comment');
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/home?tab=events'),
        title: const Text('Event thread'),
      ),
      body: Column(
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      final author = c['author'] as Map<String, dynamic>?;
                      final name = author == null ? 'Member' : '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
                      return ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        subtitle: Text(c['body'] as String? ?? '', style: const TextStyle(fontSize: 17)),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(hintText: 'Write a comment', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(backgroundColor: AppColors.gold),
                    icon: const Icon(Icons.send, color: AppColors.black),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
