import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Initials avatar with gold ring; shows a star badge for founding members.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.size = 44, this.founding = false, this.imageUrl, this.heroTag});

  final String name;
  final double size;
  final bool founding;
  final String? imageUrl;
  final Object? heroTag;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Deterministic warm tone per name so the directory feels varied.
  static List<Color> tone(String name) {
    const tones = [
      [Color(0xFF3A2E15), Color(0xFF6B5428)],
      [Color(0xFF1F2A33), Color(0xFF3B5163)],
      [Color(0xFF2E1F24), Color(0xFF5A3A44)],
      [Color(0xFF1F2B24), Color(0xFF3C5446)],
      [Color(0xFF2A2433), Color(0xFF4A3F5C)],
    ];
    final h = name.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return tones[h % tones.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = tone(name);
    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: founding ? AppColors.gold : AppColors.gold.withValues(alpha: 0.35), width: size > 60 ? 3 : 1.5),
        image: imageUrl == null ? null : DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: imageUrl != null
          ? null
          : Text(
              initials(name),
              style: TextStyle(fontFamily: AppFonts.serif, fontSize: size * 0.38, fontWeight: FontWeight.w600, color: AppColors.champagne),
            ),
    );
    if (heroTag != null) circle = Hero(tag: heroTag!, child: circle);
    final badge = size * 0.36;
    return Semantics(
      label: founding ? '$name, founding member' : name,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              if (founding)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: badge.clamp(16, 30),
                    height: badge.clamp(16, 30),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: Icon(Icons.star_rounded, size: (badge * 0.66).clamp(10, 20), color: AppColors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline "Founding" label used next to names.
class FoundingBadge extends StatelessWidget {
  const FoundingBadge({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Founding member',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.gold, AppColors.champagne]),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 12, color: AppColors.black),
            if (!compact) ...[
              const SizedBox(width: 3),
              const Text(
                'FOUNDING',
                style: TextStyle(fontFamily: AppFonts.sans, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.black),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
