import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';

class CheckinPage extends ConsumerStatefulWidget {
  const CheckinPage({super.key, required this.eventId});
  final String eventId;
  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  final tokenCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  Map<String, dynamic>? preview;
  List<dynamic> searchHits = [];
  Map<String, dynamic>? attendance;
  String? error;
  String? info;

  @override
  void initState() {
    super.initState();
    _refreshAttendance();
  }

  Future<void> _refreshAttendance() async {
    try {
      attendance = await ref.read(adminRepositoryProvider).attendance(widget.eventId);
      setState(() {});
    } catch (_) {}
  }

  Future<void> _preview(String token) async {
    setState(() {
      error = null;
      info = null;
      preview = null;
    });
    try {
      preview = await ref.read(adminRepositoryProvider).previewCheckin(widget.eventId, token);
    } on Failure catch (e) {
      error = e.message;
    }
    setState(() {});
  }

  Future<void> _confirm() async {
    if (tokenCtrl.text.trim().isEmpty && preview == null) return;
    final token = tokenCtrl.text.trim();
    try {
      await ref.read(adminRepositoryProvider).confirmCheckin(widget.eventId, token);
      info = 'Checked in ${preview?['member']?['firstName'] ?? ''}';
      preview = null;
      tokenCtrl.clear();
      await _refreshAttendance();
    } on Failure catch (e) {
      error = e.message;
    }
    setState(() {});
  }

  Future<void> _search() async {
    try {
      searchHits = await ref.read(adminRepositoryProvider).searchCheckin(widget.eventId, searchCtrl.text.trim());
      setState(() {});
    } on Failure catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _manual(String userId, {bool walkIn = false}) async {
    try {
      await ref.read(adminRepositoryProvider).manualCheckin(widget.eventId, userId, walkIn: walkIn);
      info = walkIn ? 'Walk-in checked in' : 'Manual check-in done';
      await _search();
      await _refreshAttendance();
    } on Failure catch (e) {
      error = e.message;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                Text('Check-in', style: Theme.of(context).textTheme.headlineMedium),
                Text('Live: going ${attendance?['going']} · in ${attendance?['checkedIn']} · waitlist ${attendance?['waitlisted']}'),
                if (error != null) Text(error!, style: const TextStyle(color: AppColors.error)),
                if (info != null) Text(info!, style: const TextStyle(color: AppColors.gold)),
                const SizedBox(height: 12),
                if (!kIsWeb)
                  SizedBox(
                    height: 240,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
                        if (raw != null && raw.startsWith('pm1.')) {
                          tokenCtrl.text = raw;
                          _preview(raw);
                        }
                      },
                    ),
                  )
                else
                  const Text(
                    'Camera scanning is available on mobile builds. On web, paste the QR token or use manual search.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: tokenCtrl,
                  decoration: const InputDecoration(labelText: 'QR token (manual / web fallback)'),
                ),
                Row(
                  children: [
                    OutlinedButton(onPressed: () => _preview(tokenCtrl.text.trim()), child: const Text('Preview')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: preview == null || preview?['alreadyCheckedIn'] == true ? null : _confirm,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                      child: const Text('Confirm check-in'),
                    ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${preview!['member']?['firstName']} ${preview!['member']?['lastName']}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  Text('${preview!['member']?['company'] ?? ''} · payment ${preview!['paymentStatus']}'),
                  if (preview!['alreadyCheckedIn'] == true) const Text('Already checked in', style: TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: ListView(
              children: [
                const Text('Manual search (backup)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name / email / company',
                    suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                for (final h in searchHits)
                  ListTile(
                    title: Text('${h['firstName']} ${h['lastName']}'),
                    subtitle: Text('${h['email']} · RSVP ${h['rsvpStatus'] ?? 'none'} · ${h['checkedIn'] == true ? 'IN' : 'not in'}'),
                    trailing: h['checkedIn'] == true
                        ? null
                        : Wrap(
                            children: [
                              TextButton(onPressed: () => _manual(h['id'] as String), child: const Text('Check in')),
                              TextButton(onPressed: () => _manual(h['id'] as String, walkIn: true), child: const Text('Walk-in')),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
