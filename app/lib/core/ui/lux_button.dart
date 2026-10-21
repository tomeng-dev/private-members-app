import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum LuxButtonVariant { primary, secondary, ghost, danger }

/// Primary action button with built-in loading state and 52dp height.
class LuxButton extends StatelessWidget {
  const LuxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = LuxButtonVariant.primary,
    this.loading = false,
    this.expand = false,
    this.semanticsLabel,
  });

  const LuxButton.secondary({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.expand = false, this.semanticsLabel})
    : variant = LuxButtonVariant.secondary;
  const LuxButton.ghost({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.expand = false, this.semanticsLabel})
    : variant = LuxButtonVariant.ghost;
  const LuxButton.danger({super.key, required this.label, this.onPressed, this.icon, this.loading = false, this.expand = false, this.semanticsLabel})
    : variant = LuxButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LuxButtonVariant variant;
  final bool loading;
  final bool expand;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    final onTap = loading ? null : onPressed;
    final fg = switch (variant) {
      LuxButtonVariant.primary => AppColors.black,
      LuxButtonVariant.danger => Colors.white,
      _ => variant == LuxButtonVariant.ghost ? lux.accentText : lux.textPrimary,
    };
    final child = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.sm)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    final Widget btn = switch (variant) {
      LuxButtonVariant.primary => FilledButton(onPressed: onTap, child: child),
      LuxButtonVariant.secondary => OutlinedButton(onPressed: onTap, child: child),
      LuxButtonVariant.ghost => TextButton(onPressed: onTap, child: child),
      LuxButtonVariant.danger => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: lux.danger, foregroundColor: Colors.white),
        onPressed: onTap,
        child: child,
      ),
    };
    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: onTap != null,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}
