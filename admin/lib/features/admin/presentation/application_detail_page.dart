import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';
import 'shell.dart';

/// Single application review: applicant summary, vehicle & proof, decision panel.
class ApplicationDetailPage extends ConsumerStatefulWidget {
  const ApplicationDetailPage({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends ConsumerState<ApplicationDetailPage> {
  Map<String, dynamic>? app;
  bool loading = true;
  bool busy = false;
  String? error;
  final note = TextEditingController();
  bool founding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      app = await ref.read(adminRepositoryProvider).getApplication(widget.id);
      founding = app?['foundingRequested'] == true;
    } on Failure catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _review(String decision) async {
    final name = fullName(app);
    String? message;
    if (decision == 'approve') {
      message = await confirmAction(
        context,
        title: 'Approve $name?',
        message: 'A member account is created and a set-password email is sent${founding ? ' with founding status (if under the cap)' : ''}.',
        confirmLabel: 'Approve',
      );
    } else {
      message = await confirmAction(
        context,
        title: decision == 'decline' ? 'Decline $name?' : 'Request more information?',
        message: decision == 'decline' ? 'The applicant is notified by email.' : 'The applicant receives your message and can update their application.',
        confirmLabel: decision == 'decline' ? 'Decline' : 'Send request',
        destructive: decision == 'decline',
        reasonLabel: decision == 'decline' ? 'Reason (shared with applicant)' : 'Message to applicant',
      );
    }
    if (message == null) return;
    setState(() => busy = true);
    try {
      await ref.read(adminRepositoryProvider).review(widget.id, {
        'decision': decision,
        if (note.text.trim().isNotEmpty) 'internalNote': note.text.trim(),
        if (decision == 'decline') 'declineReason': message,
        if (decision == 'more_info') 'moreInfoMessage': message,
        'grantFoundingMember': founding,
      });
      if (!mounted) return;
      showToast(context, switch (decision) {
        'approve' => '$name approved',
        'decline' => '$name declined',
        _ => 'Request sent',
      }, kind: ToastKind.success);
      ref.invalidate(consoleStatsProvider);
      context.go('/applications');
    } on Failure catch (e) {
      if (mounted) showToast(context, e.message, kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(Gap.xxl),
        child: Card(child: TableSkeleton(rows: 5)),
      );
    }
    if (app == null) return ErrorView(message: error ?? 'Not found', onRetry: _load);
    final a = app!;
    final proofs = ((a['proofMedia'] as List?) ?? const []).cast<Map>();
    final decided = a['status'] == 'approved' || a['status'] == 'declined';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Applicant',
          child: Column(
            children: [
              InfoRow('Email', '${a['email']}'),
              InfoRow('Phone', '${a['phone'] ?? '—'}'),
              InfoRow('Company', [a['company'], a['title']].where((e) => e != null).join(' · ')),
              InfoRow('Location', [a['city'], a['state']].where((e) => e != null).join(', ')),
              InfoRow('Source', a['invite'] == null ? 'Direct application' : 'Invite code ${(a['invite'] as Map)['code']}'),
              InfoRow('Submitted', fmtDate(a['createdAt'], time: true)),
              InfoRow('Consents', 'Privacy ${a['consentPrivacyVersion'] ?? '—'} · Terms ${a['consentTermsVersion'] ?? '—'}'),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: 'Vehicle',
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: context.tokens.surfaceRaised, borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(Icons.directions_car_filled_outlined, color: context.tokens.accentText, size: 28),
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a['vehicleYear']} ${a['vehicleMake']} ${a['vehicleModel']}', style: context.text.headlineSmall),
                    Text('Estimated value ${fmtUsd(a['vehicleEstimatedValue'] as num?)}', style: context.text.bodySmall?.copyWith(fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: 'Ownership proof',
          subtitle: 'Stored privately; viewable by staff only',
          child: proofs.isEmpty
              ? Text('No proof uploaded.', style: context.text.bodySmall)
              : Column(
                  children: [
                    for (final p in proofs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(p['mimeType'].toString().contains('pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
                        title: Text(humanize('${p['kind']}')),
                        subtitle: Text('${p['mimeType']}', style: context.text.bodySmall),
                        trailing: const StatusChip('secure', label: 'Private', tone: Tone.success, dense: true),
                      ),
                  ],
                ),
        ),
      ],
    );
    final decision = SectionCard(
      title: 'Decision',
      trailing: StatusChip('${a['status']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (a['declineReason'] != null) InfoRow('Decline reason', '${a['declineReason']}'),
          if (a['moreInfoMessage'] != null) InfoRow('Info requested', '${a['moreInfoMessage']}'),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: 'Internal note (staff only)', hintText: a['internalNote']?.toString()),
          ),
          const SizedBox(height: Gap.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Grant founding membership'),
            subtitle: Text(
              a['foundingRequested'] == true ? 'Applicant requested founding status' : 'Only while under the founding cap',
              style: context.text.bodySmall,
            ),
            value: founding,
            onChanged: decided ? null : (v) => setState(() => founding = v),
          ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            onPressed: decided || busy ? null : () => _review('approve'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            onPressed: decided || busy ? null : () => _review('more_info'),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Request more info'),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.tokens.danger),
            onPressed: decided || busy ? null : () => _review('decline'),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Decline'),
          ),
          if (decided) ...[const SizedBox(height: Gap.md), Text('Reviewed ${fmtDate(a['reviewedAt'], time: true)}', style: context.text.bodySmall)],
        ],
      ),
    );
    return PageScaffold(
      scroll: true,
      title: fullName(a),
      subtitle: 'Membership application · ${humanize('${a['status']}')}',
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/applications'),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('All applications'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 980
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: details),
                  const SizedBox(width: Gap.lg),
                  SizedBox(width: 360, child: decision),
                ],
              )
            : Column(
                children: [
                  decision,
                  const SizedBox(height: Gap.lg),
                  details,
                ],
              ),
      ),
    );
  }
}
