import 'package:flutter/material.dart';
import '../theme/tokens.dart';

enum ScreenSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  ScreenSize get screenSize {
    final w = screenWidth;
    if (w < AppBreakpoints.compact) return ScreenSize.compact;
    if (w < AppBreakpoints.medium) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
}

/// Centers content with a max width and responsive gutters.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth = AppBreakpoints.contentMaxWidth});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Page gutter that grows on bigger screens.
EdgeInsets pagePadding(BuildContext context, {double top = AppSpacing.lg, double bottom = AppSpacing.xxl}) {
  final h = context.isCompact ? AppSpacing.lg : AppSpacing.xl;
  return EdgeInsets.fromLTRB(h, top, h, bottom);
}

/// Column count for card grids given available width and min tile width.
int gridColumns(double width, {double minTile = 320, int max = 4}) => (width / minTile).floor().clamp(1, max);
