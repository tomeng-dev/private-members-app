import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'lux_button.dart';

/// Friendly empty state with icon, title, message and optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final lux = context.lux;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lux.accent.withValues(alpha: 0.12),
                  border: Border.all(color: lux.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, size: 34, color: lux.accentText),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: lux.textMuted),
                ),
              ],
              if (actionLabel != null) ...[const SizedBox(height: AppSpacing.xl), LuxButton(label: actionLabel!, onPressed: onAction)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Something went wrong',
    message: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// Inline error banner for forms.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final c = context.lux.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: c, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: context.text.bodyMedium?.copyWith(color: c)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = AppRadii.sm, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDark ? const Color(0xFF1E1E22) : const Color(0xFFECE6DA);
    final hi = context.isDark ? const Color(0xFF2A2A30) : const Color(0xFFF7F3EA);
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = disable ? 0.5 : _c.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
              gradient: LinearGradient(begin: Alignment(-1.5 + 3 * t, 0), end: Alignment(-0.5 + 3 * t, 0), colors: [base, hi, base]),
            ),
          );
        },
      ),
    );
  }
}

/// Card-shaped skeleton for feed/list loading.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.withAvatar = true, this.media = false});
  final int lines;
  final bool withAvatar;
  final bool media;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.lux.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: context.lux.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (media) ...[const Skeleton(height: 140, radius: AppRadii.md), const SizedBox(height: AppSpacing.lg)],
          if (withAvatar)
            const Row(
              children: [
                Skeleton(width: 44, height: 44, circle: true),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Skeleton(width: 140), SizedBox(height: 8), Skeleton(width: 90, height: 12)],
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < lines; i++) ...[Skeleton(width: i == lines - 1 ? 180 : double.infinity), const SizedBox(height: AppSpacing.sm)],
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.media = false, this.padding = const EdgeInsets.all(AppSpacing.lg)});
  final int count;
  final bool media;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => SkeletonCard(media: media),
    ),
  );
}
