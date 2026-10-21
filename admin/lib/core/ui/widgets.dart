import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

String humanize(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final s = raw.replaceAll('_', ' ').replaceAll('.', ' · ');
  return s[0].toUpperCase() + s.substring(1);
}

String fmtDate(dynamic iso, {bool time = false}) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '—';
  return time ? DateFormat('MMM d, y · h:mm a').format(d) : DateFormat('MMM d, y').format(d);
}

String fmtRelative(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(d);
}

String fmtUsd(num? v, {bool cents = false}) {
  if (v == null) return '—';
  final n = cents ? v / 100 : v;
  return NumberFormat.compactSimpleCurrency(decimalDigits: n >= 1000 ? 0 : 2).format(n);
}

String fullName(Map<String, dynamic>? m) {
  if (m == null) return '—';
  final n = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
  return n.isEmpty ? '${m['email'] ?? '—'}' : n;
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// Standard page frame: serif title, optional subtitle, right-aligned actions.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, this.subtitle, this.actions = const [], required this.child, this.scroll = false, this.maxWidth = 1440});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final bool scroll;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xxl, Gap.xl, Gap.xxl, Gap.lg),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: Gap.md,
        spacing: Gap.lg,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
              if (subtitle != null) ...[const SizedBox(height: Gap.xs), Text(subtitle!, style: context.text.bodySmall?.copyWith(fontSize: 13.5))],
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: actions),
        ],
      ),
    );
    final body = Padding(padding: const EdgeInsets.fromLTRB(Gap.xxl, 0, Gap.xxl, Gap.xxl), child: child);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scroll
            ? ListView(padding: EdgeInsets.zero, children: [header, body])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.subtitle, this.trailing, required this.child, this.padding = const EdgeInsets.all(Gap.xl)});
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: context.text.titleMedium),
                        if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: Gap.lg),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status chips
// ---------------------------------------------------------------------------

enum Tone { neutral, success, warning, danger, info, accent }

Tone toneForStatus(String? s) {
  switch (s) {
    case 'active':
    case 'approved':
    case 'published':
    case 'paid':
    case 'going':
    case 'resolved':
    case 'checked_in':
      return Tone.success;
    case 'submitted':
    case 'pending':
    case 'pending_password':
    case 'dues_due':
    case 'unpaid':
    case 'waitlisted':
    case 'draft':
      return Tone.warning;
    case 'under_review':
    case 'more_info_needed':
    case 'open':
      return Tone.info;
    case 'declined':
    case 'rejected':
    case 'suspended':
    case 'overdue':
    case 'cancelled':
    case 'revoked':
    case 'banned':
      return Tone.danger;
    case 'founding':
    case 'super_admin':
    case 'admin':
      return Tone.accent;
    default:
      return Tone.neutral;
  }
}

Color toneColor(BuildContext context, Tone tone) {
  final t = context.tokens;
  return switch (tone) {
    Tone.success => t.success,
    Tone.warning => t.warning,
    Tone.danger => t.danger,
    Tone.info => t.info,
    Tone.accent => t.accentText,
    Tone.neutral => t.textMuted,
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label, this.tone, this.dense = false});
  final String? status;
  final String? label;
  final Tone? tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = toneColor(context, tone ?? toneForStatus(status));
    final text = label ?? humanize(status);
    return Semantics(
      label: 'Status: $text',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 2 : 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: dense ? 11.5 : 12, fontWeight: FontWeight.w600, color: c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 32, this.founding = false});
  final String name;
  final double size;
  final bool founding;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static const _tones = [Color(0xFF4A3A2A), Color(0xFF2A3A4A), Color(0xFF3A2A3A), Color(0xFF2A4A3A), Color(0xFF4A4A2A)];

  @override
  Widget build(BuildContext context) {
    final bg = _tones[name.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];
    return Semantics(
      label: founding ? '$name, founding member' : name,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: founding ? AppColors.gold : Colors.white12, width: founding ? 1.5 : 1),
              ),
              child: Text(
                initials(name),
                style: TextStyle(fontFamily: AppFonts.serif, fontSize: size * 0.4, color: AppColors.champagne, fontWeight: FontWeight.w600),
              ),
            ),
            if (founding)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.tokens.surface, width: 1.5),
                  ),
                  child: Icon(Icons.star_rounded, size: size * 0.28, color: AppColors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI card
// ---------------------------------------------------------------------------

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.label, required this.value, required this.icon, this.caption, this.onTap, this.tone = Tone.accent});
  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final VoidCallback? onTap;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColor(context, tone);
    return Semantics(
      button: onTap != null,
      label: '$label: $value${caption != null ? ', $caption' : ''}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg + 2),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(Radii.md)),
                  child: Icon(icon, color: c, size: 22),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(), style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(value, style: context.text.headlineSmall?.copyWith(fontSize: 24)),
                      if (caption != null) Text(caption!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right_rounded, color: context.tokens.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error / loading
// ---------------------------------------------------------------------------

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.action});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.tokens.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: context.tokens.border),
              ),
              child: Icon(icon, color: context.tokens.accentText),
            ),
            const SizedBox(height: Gap.lg),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[const SizedBox(height: Gap.xs), Text(message!, style: context.text.bodySmall, textAlign: TextAlign.center)],
            if (action != null) ...[const SizedBox(height: Gap.lg), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: message,
      action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry')),
    );
  }
}

/// Pulsing placeholder block; excluded from semantics.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = Radii.sm});
  final double? width;
  final double height;
  final double radius;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.tokens.surfaceRaised;
    final hi = context.isDark ? AppColors.surface3 : const Color(0xFFE6E2DA);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: Color.lerp(base, hi, _c.value), borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

class TableSkeleton extends StatelessWidget {
  const TableSkeleton({super.key, this.rows = 8});
  final int rows;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 14),
              child: Row(
                children: [
                  const SkeletonBox(width: 18, height: 18),
                  const SizedBox(width: Gap.lg),
                  const SkeletonBox(width: 32, height: 32, radius: 16),
                  const SizedBox(width: Gap.md),
                  Expanded(flex: 3, child: SkeletonBox(width: 120.0 + (i % 3) * 30)),
                  const SizedBox(width: Gap.xl),
                  const Expanded(flex: 2, child: SkeletonBox(width: 80)),
                  const SizedBox(width: Gap.xl),
                  const Expanded(child: SkeletonBox(width: 60)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback: toasts & dialogs
// ---------------------------------------------------------------------------

enum ToastKind { info, success, error }

void showToast(BuildContext context, String message, {ToastKind kind = ToastKind.info}) {
  final icon = switch (kind) {
    ToastKind.success => Icons.check_circle_rounded,
    ToastKind.error => Icons.error_rounded,
    ToastKind.info => Icons.info_rounded,
  };
  final color = switch (kind) {
    ToastKind.success => AppColors.success,
    ToastKind.error => AppColors.error,
    ToastKind.info => AppColors.gold,
  };
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Confirmation dialog. When [reasonLabel] is set the user must enter a reason
/// (min [minReason] chars) and it is returned; otherwise returns '' on confirm.
/// Returns null when cancelled.
Future<String?> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  String? reasonLabel,
  int minReason = 3,
}) {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final danger = ctx.tokens.danger;
      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message, style: ctx.text.bodyMedium),
                if (reasonLabel != null) ...[
                  const SizedBox(height: Gap.lg),
                  TextFormField(
                    controller: ctrl,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(labelText: reasonLabel, alignLabelWithHint: true),
                    validator: (v) => (v ?? '').trim().length < minReason ? 'Please enter at least $minReason characters' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: danger, foregroundColor: Colors.white) : null,
            onPressed: () {
              if (reasonLabel != null && !(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}

/// Small labelled key/value row used in drawers and detail pages.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.trailing});
  final String label;
  final String value;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: context.text.bodySmall?.copyWith(fontSize: 13))),
          Expanded(child: SelectableText(value, style: context.text.bodyMedium)),
          ?trailing,
        ],
      ),
    );
  }
}
