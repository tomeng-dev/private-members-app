import 'package:flutter/material.dart';
import 'tokens.dart';

/// Brand palette. Dark is the default theme (see CLAUDE.md "Design system"):
/// evening events, luxury automotive brand language (black/gold), and lower
/// glare for older eyes in low light. Light theme is fully supported.
class AppColors {
  AppColors._();
  // Brand
  static const Color gold = Color(0xFFC9A961); // accent on dark (9.6:1 on ink)
  static const Color goldDeep = Color(0xFF8A6A25); // accent text on light (5.0:1 on ivory)
  static const Color goldDark = Color(0xFF9A7B3C);
  static const Color champagne = Color(0xFFE9D9B0);
  // Dark surfaces
  static const Color black = Color(0xFF0A0A0B); // ink / background
  static const Color softBlack = Color(0xFF141416); // surface
  static const Color surface2 = Color(0xFF1C1C1F); // raised surface
  static const Color surface3 = Color(0xFF26262A); // hover / input
  static const Color hairline = Color(0xFF2E2E33);
  // Light surfaces
  static const Color ivory = Color(0xFFFAF8F3);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color sand = Color(0xFFF1ECE2);
  static const Color hairlineLight = Color(0xFFE3DDD0);
  // Text
  static const Color white = Color(0xFFF5F3EE);
  static const Color muted = Color(0xFF9B968E); // 6.6:1 on ink
  static const Color ink = Color(0xFF1A1917);
  static const Color mutedLight = Color(0xFF615C54); // 6.2:1 on ivory
  // Status
  static const Color success = Color(0xFF4CAF7A);
  static const Color warning = Color(0xFFE0A33B);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF5B9BD5);
}

/// Semantic tokens that vary by brightness, available via
/// `Theme.of(context).extension<LuxTokens>()!` or `context.lux`.
@immutable
class LuxTokens extends ThemeExtension<LuxTokens> {
  const LuxTokens({
    required this.accent,
    required this.accentText,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.heroGradient,
  });

  final Color accent;
  final Color accentText;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final List<Color> heroGradient;

  static const dark = LuxTokens(
    accent: AppColors.gold,
    accentText: AppColors.gold,
    surface: AppColors.softBlack,
    surfaceRaised: AppColors.surface2,
    surfaceSunken: AppColors.black,
    border: AppColors.hairline,
    textPrimary: AppColors.white,
    textMuted: AppColors.muted,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    heroGradient: [Color(0xFF0A0A0B), Color(0xFF1B1710), Color(0xFF3A2E15)],
  );

  static const light = LuxTokens(
    accent: AppColors.gold,
    accentText: AppColors.goldDeep,
    surface: AppColors.paper,
    surfaceRaised: AppColors.paper,
    surfaceSunken: AppColors.sand,
    border: AppColors.hairlineLight,
    textPrimary: AppColors.ink,
    textMuted: AppColors.mutedLight,
    success: Color(0xFF1E7A4C),
    warning: Color(0xFF8F5B00),
    danger: Color(0xFFC4262C),
    heroGradient: [Color(0xFF15130F), Color(0xFF2B2416), Color(0xFF5A4520)],
  );

  @override
  LuxTokens copyWith({Color? accent}) => LuxTokens(
    accent: accent ?? this.accent,
    accentText: accentText,
    surface: surface,
    surfaceRaised: surfaceRaised,
    surfaceSunken: surfaceSunken,
    border: border,
    textPrimary: textPrimary,
    textMuted: textMuted,
    success: success,
    warning: warning,
    danger: danger,
    heroGradient: heroGradient,
  );

  @override
  LuxTokens lerp(ThemeExtension<LuxTokens>? other, double t) {
    if (other is! LuxTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LuxTokens(
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textMuted: l(textMuted, other.textMuted),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      heroGradient: t < 0.5 ? heroGradient : other.heroGradient,
    );
  }
}

extension LuxContext on BuildContext {
  LuxTokens get lux => Theme.of(this).extension<LuxTokens>() ?? LuxTokens.dark;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppFonts {
  AppFonts._();
  static const String serif = 'PlayfairDisplay';
  static const String sans = 'Inter';
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static TextTheme _text(Color primary, Color muted) {
    TextStyle serif(double size, FontWeight w, {double h = 1.2, double ls = 0}) =>
        TextStyle(fontFamily: AppFonts.serif, fontSize: size, fontWeight: w, height: h, letterSpacing: ls, color: primary);
    TextStyle sans(double size, FontWeight w, {double h = 1.45, double ls = 0, Color? c}) =>
        TextStyle(fontFamily: AppFonts.sans, fontSize: size, fontWeight: w, height: h, letterSpacing: ls, color: c ?? primary);
    return TextTheme(
      displayLarge: serif(48, FontWeight.w600, h: 1.1, ls: -0.5),
      displayMedium: serif(40, FontWeight.w600, h: 1.1, ls: -0.5),
      displaySmall: serif(34, FontWeight.w600, h: 1.15),
      headlineLarge: serif(30, FontWeight.w600),
      headlineMedium: serif(26, FontWeight.w600),
      headlineSmall: serif(22, FontWeight.w600),
      titleLarge: sans(20, FontWeight.w600, h: 1.3),
      titleMedium: sans(17, FontWeight.w600, h: 1.35),
      titleSmall: sans(15, FontWeight.w600, h: 1.35),
      bodyLarge: sans(17, FontWeight.w400, h: 1.5),
      bodyMedium: sans(16, FontWeight.w400, h: 1.5),
      bodySmall: sans(14, FontWeight.w400, h: 1.45, c: muted),
      labelLarge: sans(16, FontWeight.w600, ls: 0.2),
      labelMedium: sans(14, FontWeight.w600, ls: 0.2),
      labelSmall: sans(12, FontWeight.w600, ls: 0.8),
    );
  }

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final t = isDark ? LuxTokens.dark : LuxTokens.light;
    final bg = isDark ? AppColors.black : AppColors.ivory;
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.gold,
      onPrimary: AppColors.black,
      primaryContainer: isDark ? const Color(0xFF3A2E15) : AppColors.champagne,
      onPrimaryContainer: isDark ? AppColors.champagne : AppColors.ink,
      secondary: t.accentText,
      onSecondary: isDark ? AppColors.black : Colors.white,
      surface: t.surface,
      onSurface: t.textPrimary,
      onSurfaceVariant: t.textMuted,
      surfaceContainerLowest: bg,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surfaceRaised,
      surfaceContainerHigh: isDark ? AppColors.surface3 : AppColors.sand,
      surfaceContainerHighest: isDark ? AppColors.surface3 : AppColors.sand,
      outline: t.border,
      outlineVariant: t.border,
      error: t.danger,
      onError: Colors.white,
    );
    final text = _text(t.textPrimary, t.textMuted);
    final shape = RoundedRectangleBorder(borderRadius: AppRadii.button);
    const minButton = Size(64, 52);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      textTheme: text,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: t.border,
      extensions: [t],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.flat,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: t.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          minimumSize: minButton,
          elevation: 0,
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          minimumSize: minButton,
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: isDark ? const Color(0xFF4A4740) : const Color(0xFFCFC6B4), width: 1.2),
          minimumSize: minButton,
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentText,
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          textStyle: text.labelLarge,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(kMinTapTarget, kMinTapTarget))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surface2 : AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        border: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide(color: t.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide(color: t.danger, width: 1.6),
        ),
        labelStyle: TextStyle(fontSize: 16, color: t.textMuted),
        floatingLabelStyle: TextStyle(fontSize: 16, color: t.accentText),
        hintStyle: TextStyle(fontSize: 16, color: t.textMuted),
        errorStyle: TextStyle(fontSize: 14, color: t.danger),
        prefixIconColor: t.textMuted,
        suffixIconColor: t.textMuted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: isDark ? const Color(0xFF3A2E15) : AppColors.champagne,
        side: BorderSide(color: t.border),
        labelStyle: text.labelMedium,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        checkmarkColor: t.accentText,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? const Color(0xFF3A2E15) : AppColors.champagne,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? t.textPrimary : t.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? t.accentText : t.textMuted)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.surface,
        indicatorColor: isDark ? const Color(0xFF3A2E15) : AppColors.champagne,
        selectedIconTheme: IconThemeData(color: t.accentText, size: 26),
        unselectedIconTheme: IconThemeData(color: t.textMuted, size: 26),
        selectedLabelTextStyle: text.labelLarge,
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: t.textMuted, fontWeight: FontWeight.w500),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surface3 : AppColors.ink,
        contentTextStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 15, color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textMuted,
        indicatorColor: AppColors.gold,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        dividerColor: t.border,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(kMinTapTarget, kMinTapTarget),
          selectedBackgroundColor: isDark ? const Color(0xFF3A2E15) : AppColors.champagne,
          selectedForegroundColor: t.textPrimary,
          foregroundColor: t.textMuted,
          side: BorderSide(color: t.border),
          textStyle: text.labelMedium,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textMuted,
        textColor: t.textPrimary,
        minTileHeight: 56,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
        checkColor: const WidgetStatePropertyAll(AppColors.black),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.black : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: t.border),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: isDark ? AppColors.surface3 : AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.sm)),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 13),
      ),
    );
  }
}
