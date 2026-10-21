import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'lux_button.dart';

enum ToastKind { info, success, error }

/// Floating toast (SnackBar) with icon; announced to screen readers.
void showToast(BuildContext context, String message, {ToastKind kind = ToastKind.info}) {
  final lux = context.lux;
  final (icon, color) = switch (kind) {
    ToastKind.success => (Icons.check_circle_outline, lux.success),
    ToastKind.error => (Icons.error_outline, lux.danger),
    ToastKind.info => (Icons.info_outline, AppColors.gold),
  };
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color == lux.success ? AppColors.success : color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Confirm dialog; returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      actions: [
        LuxButton.ghost(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false)),
        destructive
            ? LuxButton.danger(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true))
            : LuxButton(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return res ?? false;
}

/// Text-input dialog (e.g. report reason). Returns null on cancel.
Future<String?> showInputDialog(BuildContext context, {required String title, required String label, String confirmLabel = 'Submit'}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        LuxButton.ghost(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
        LuxButton(label: confirmLabel, onPressed: () => Navigator.pop(ctx, c.text.trim())),
      ],
    ),
  );
}

/// Modal bottom sheet with title, constrained width on large screens.
Future<T?> showLuxSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
            child: Semantics(header: true, child: Text(title, style: Theme.of(ctx).textTheme.headlineSmall)),
          ),
          Flexible(child: builder(ctx)),
        ],
      ),
    ),
  );
}
