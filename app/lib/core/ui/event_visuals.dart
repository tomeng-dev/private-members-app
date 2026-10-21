import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Elegant generated cover used until an event has a cover image.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.seed,
    this.height = 160,
    this.borderRadius,
    this.child,
    this.icon = Icons.directions_car_filled_outlined,
    this.showIcon = true,
  });
  final bool showIcon;
  final String seed;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? child;
  final IconData icon;

  static const _palettes = [
    [Color(0xFF14110B), Color(0xFF3A2E15), Color(0xFF8A6A25)],
    [Color(0xFF0D1217), Color(0xFF1F3344), Color(0xFF5B7A8F)],
    [Color(0xFF140D0F), Color(0xFF3B1E26), Color(0xFF8C4A5A)],
    [Color(0xFF0C120E), Color(0xFF1E3326), Color(0xFF5C8A6E)],
  ];

  @override
  Widget build(BuildContext context) {
    final h = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final p = _palettes[h % _palettes.length];
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: height.isFinite ? height : null,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, c) {
            final boxH = c.maxHeight.isFinite ? c.maxHeight : (height.isFinite ? height : 300.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p, stops: const [0, 0.6, 1]),
                  ),
                ),
                CustomPaint(painter: _LinesPainter(seed: h)),
                if (showIcon)
                  Align(
                    alignment: const Alignment(0.85, -0.2),
                    child: Icon(icon, size: (boxH * 0.42).clamp(24.0, 140.0), color: Colors.white.withValues(alpha: 0.10)),
                  ),
                if (child != null) child!,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({required this.seed});
  final int seed;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gold.withValues(alpha: 0.22);
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y = size.height * (0.35 + i * 0.13);
      path.moveTo(-20, y + (seed % 30));
      path.cubicTo(size.width * 0.3, y - 40 - i * 6, size.width * 0.6, y + 50, size.width + 20, y - 10 - (seed % 20));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => old.seed != seed;
}

/// Calendar-style date badge (e.g. "OCT / 26").
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, this.size = 56});
  final DateTime date;
  final double size;
  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    return Semantics(
      label: DateFormat.yMMMMd().format(local),
      child: Container(
        width: size,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xE60A0A0B) : const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.MMM().format(local).toUpperCase(),
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: context.lux.accentText,
                ),
              ),
              Text(
                '${local.day}',
                style: TextStyle(fontFamily: AppFonts.serif, fontSize: size * 0.42, fontWeight: FontWeight.w600, height: 1.1, color: context.lux.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2h", "3d", "Oct 2" style relative time.
String relativeTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return DateFormat.MMMd().format(t.toLocal());
}
