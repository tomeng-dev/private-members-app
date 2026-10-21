import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../core/ui/ui.dart';

/// Edit membership standing / founding flag. Returns true when saved.
Future<bool> showDuesDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
  String status = m['membershipStatus'] as String? ?? 'dues_due';
  bool founding = m['foundingMember'] as bool? ?? false;
  final refCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Dues · ${fullName(m)}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active (paid)')),
                  DropdownMenuItem(value: 'dues_due', child: Text('Dues due')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (v) => setLocal(() => status = v ?? status),
                decoration: const InputDecoration(labelText: 'Membership status'),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'External payment reference (optional)'),
              ),
              const SizedBox(height: Gap.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Founding member'),
                value: founding,
                onChanged: (v) => setLocal(() => founding = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    ),
  );
  if (saved != true) return false;
  try {
    await ref.read(adminRepositoryProvider).updateDues(m['id'] as String, {
      'membershipStatus': status,
      if (refCtrl.text.trim().isNotEmpty) 'externalRef': refCtrl.text.trim(),
      'foundingMember': founding,
    });
    if (context.mounted) showToast(context, 'Dues updated', kind: ToastKind.success);
    return true;
  } on Failure catch (e) {
    if (context.mounted) showToast(context, e.message, kind: ToastKind.error);
    return false;
  }
}

const assignableRoles = ['member', 'moderator', 'admin', 'super_admin'];

String roleDescription(String r) => switch (r) {
  'member' => 'Member app access',
  'moderator' => 'Reports, content moderation, check-in',
  'admin' => 'Applications, members, events, dues, broadcast',
  'super_admin' => 'Everything, including staff roles',
  _ => '',
};

/// Edit staff roles. Returns true when saved.
Future<bool> showRolesDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
  final roles = {...((m['roles'] as List?) ?? const []).map((e) => '$e')};
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text('Roles · ${fullName(m)}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in assignableRoles)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: roles.contains(r),
                  title: Text(humanize(r)),
                  subtitle: Text(roleDescription(r), style: ctx.text.bodySmall),
                  onChanged: (v) => setLocal(() => v == true ? roles.add(r) : roles.remove(r)),
                ),
              const SizedBox(height: Gap.sm),
              Text('Only super admins can change roles. Every change is audit-logged.', style: ctx.text.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: roles.isEmpty ? null : () => Navigator.pop(ctx, true), child: const Text('Save roles')),
        ],
      ),
    ),
  );
  if (saved != true) return false;
  try {
    await ref.read(adminRepositoryProvider).assignRoles(m['id'] as String, roles.toList());
    if (context.mounted) showToast(context, 'Roles updated', kind: ToastKind.success);
    return true;
  } on Failure catch (e) {
    if (context.mounted) showToast(context, e.message, kind: ToastKind.error);
    return false;
  }
}
