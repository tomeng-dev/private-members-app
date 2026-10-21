import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';

class EventDetailAdminPage extends ConsumerStatefulWidget {
  const EventDetailAdminPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EventDetailAdminPage> createState() => _EventDetailAdminPageState();
}

class _EventDetailAdminPageState extends ConsumerState<EventDetailAdminPage> {
  Map<String, dynamic>? event;
  Map<String, dynamic>? attendance;
  String? error;
  bool loading = true;
  final coverKey = TextEditingController();
  final speakerName = TextEditingController();
  final speakerRole = TextEditingController(text: 'guest');
  final speakerBio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    coverKey.dispose();
    speakerName.dispose();
    speakerRole.dispose();
    speakerBio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      event = await ref.read(adminRepositoryProvider).getEvent(widget.id);
      attendance = await ref.read(adminRepositoryProvider).attendance(widget.id);
      coverKey.text = event?['coverImageKey']?.toString() ?? '';
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get _speakers => ((event?['speakers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _save({String? status}) async {
    if (event == null) return;
    try {
      await ref.read(adminRepositoryProvider).updateEvent(widget.id, {
        'title': event!['title'],
        'startsAt': event!['startsAt'],
        'description': event!['description'],
        'venueName': event!['venueName'],
        'venueAddress': event!['venueAddress'],
        'timezone': event!['timezone'] ?? 'America/New_York',
        'status': status ?? event!['status'],
        'capacity': event!['capacity'],
        'feeUsdCents': event!['feeUsdCents'] ?? 100000,
        'paymentLinkUrl': event!['paymentLinkUrl'],
        'coverImageKey': coverKey.text.trim().isEmpty ? null : coverKey.text.trim(),
        'speakers': _speakers,
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event saved')));
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _togglePayment(Map<String, dynamic> rsvp) async {
    final next = rsvp['paymentStatus'] == 'paid' ? 'unpaid' : 'paid';
    try {
      await ref.read(adminRepositoryProvider).markRsvpPayment(widget.id, rsvp['id'] as String, next);
      await _load();
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  void _addSpeaker() {
    if (speakerName.text.trim().isEmpty) return;
    final list = _speakers;
    list.add({'name': speakerName.text.trim(), 'role': speakerRole.text.trim().isEmpty ? 'guest' : speakerRole.text.trim(), 'bio': speakerBio.text.trim()});
    setState(() {
      event = {...?event, 'speakers': list};
      speakerName.clear();
      speakerBio.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rsvps = ((event?['rsvps'] as List?) ?? []).cast<Map<String, dynamic>>();
    final speakers = _speakers;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(event?['title'] as String? ?? '', style: Theme.of(context).textTheme.headlineMedium)),
                    if (event?['status'] != 'published')
                      FilledButton(
                        onPressed: () => _save(status: 'published'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black, minimumSize: const Size(48, 48)),
                        child: const Text('Publish'),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => context.go('/events/${widget.id}/checkin'), child: const Text('Check-in scanner')),
                  ],
                ),
                Text(
                  'Status: ${event?['status']} · Live: going ${attendance?['going']} / checked-in ${attendance?['checkedIn']} / waitlist ${attendance?['waitlisted']}',
                ),
                if (error != null) Text(error!, style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
                Text('Cover image', style: Theme.of(context).textTheme.titleLarge),
                const Text(
                  'Paste a storage key from Media upload (ownerType=event). Preview uses signed URLs.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                TextField(
                  controller: coverKey,
                  decoration: const InputDecoration(labelText: 'coverImageKey'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: () => _save(), child: const Text('Save cover & speakers')),
                const SizedBox(height: 16),
                Text('Speakers editor', style: Theme.of(context).textTheme.titleLarge),
                for (var i = 0; i < speakers.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${speakers[i]['role']}: ${speakers[i]['name']}', style: const TextStyle(fontSize: 17)),
                    subtitle: Text('${speakers[i]['bio'] ?? speakers[i]['topic'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
                    trailing: IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final list = _speakers..removeAt(i);
                        setState(() => event = {...?event, 'speakers': list});
                      },
                    ),
                  ),
                TextField(
                  controller: speakerName,
                  decoration: const InputDecoration(labelText: 'Speaker name'),
                ),
                TextField(
                  controller: speakerRole,
                  decoration: const InputDecoration(labelText: 'Role (chef/guest/keynote/roundtable)'),
                ),
                TextField(
                  controller: speakerBio,
                  decoration: const InputDecoration(labelText: 'Bio / topic / menu notes'),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _addSpeaker, child: const Text('Add speaker')),
                const SizedBox(height: 24),
                Text('RSVPs', style: Theme.of(context).textTheme.titleLarge),
                for (final r in rsvps)
                  ListTile(
                    title: Text('${r['user']?['firstName']} ${r['user']?['lastName']} (${r['status']})'),
                    subtitle: Text('${r['user']?['email']} · payment ${r['paymentStatus']}'),
                    trailing: TextButton(
                      onPressed: () => _togglePayment(r),
                      child: Text(r['paymentStatus'] == 'paid' ? 'Mark unpaid' : 'Mark paid', style: const TextStyle(color: AppColors.gold)),
                    ),
                  ),
                const SizedBox(height: 12),
                SelectableText('CSV export: ${ref.read(adminRepositoryProvider).attendanceCsvUrl(widget.id)}'),
              ],
            ),
    );
  }
}
