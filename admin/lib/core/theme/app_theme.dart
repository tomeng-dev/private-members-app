import 'package:flutter/material.dart';

/// Brand palette shared with the member app (black / ivory / champagne gold).
class AppColors {
  static const Color black = Color(0xFF0A0A0B);
  static const Color softBlack = Color(0xFF141416);
  static const Color surface2 = Color(0xFF1B1B1E);
  static const Color surface3 = Color(0xFF242428);
  static const Color hairline = Color(0xFF2C2C31);
  static const Color white = Color(0xFFF7F5F2);
  static const Color ivory = Color(0xFFFAF8F4);
  static const Color gold = Color(0xFFC9A961);
  static const Color goldDark = Color(0xFF8A6A25);
  static const Color champagne = Color(0xFFE6D3A3);
  static const Color muted = Color(0xFF9C978F);
  static const Color error = Color(0xFFF2726F);
  static const Color success = Color(0xFF5CC489);
  static const Color warning = Color(0xFFE8B04B);
  static const Color info = Color(0xFF7EA8F8);
}

class AppFonts {
  static const serif = 'PlayfairDisplay';
  static const sans = 'Inter';
}

/// Spacing / radius scale (4-pt grid). Admin uses a denser rhythm than the member app.
class Gap {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

class Radii {
  static const double sm = 6, md = 10, lg = 14, pill = 999;
}

/// Semantic colors that vary between dark and light themes.
@immutable
class AdminTokens extends ThemeExtension<AdminTokens> {
  const AdminTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.accentText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.sidebar,
  });

  final Color canvas, surface, surfaceRaised, surfaceSunken, border, textPrimary, textMuted, accent, accentText, success, warning, danger, info, sidebar;

  static const dark = AdminTokens(
    canvas: AppColors.black,
    surface: AppColors.softBlack,
    surfaceRaised: AppColors.surface2,
    surfaceSunken: Color(0xFF0F0F11),
    border: AppColors.hairline,
    textPrimary: AppColors.white,
    textMuted: AppColors.muted,
    accent: AppColors.gold,
    accentText: AppColors.gold,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.error,
    info: AppColors.info,
    sidebar: Color(0xFF0E0E10),
  );

  static const light = AdminTokens(
    canvas: Color(0xFFF4F2EE),
    surface: Colors.white,
    surfaceRaised: Color(0xFFFBFAF8),
    surfaceSunken: Color(0xFFEDEAE4),
    border: Color(0xFFE2DDD3),
    textPrimary: Color(0xFF17171A),
    textMuted: Color(0xFF5F5A52),
    accent: AppColors.gold,
    accentText: AppColors.goldDark,
    success: Color(0xFF1E7A4A),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFB3261E),
    info: Color(0xFF2155C4),
    sidebar: Color(0xFFFFFFFF),
  );

  @override
  AdminTokens copyWith() => this;

  @override
  AdminTokens lerp(ThemeExtension<AdminTokens>? other, double t) => t < 0.5 ? this : (other as AdminTokens? ?? this);
}

extension AdminThemeX on BuildContext {
  AdminTokens get tokens => Theme.of(this).extension<AdminTokens>() ?? AdminTokens.dark;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static ThemeData get dark => _build(Brightness.dark, AdminTokens.dark);
  static ThemeData get light => _build(Brightness.light, AdminTokens.light);

  static ThemeData _build(Brightness b, AdminTokens t) {
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.gold,
      onPrimary: AppColors.black,
      secondary: t.accentText,
      onSecondary: b == Brightness.dark ? AppColors.black : Colors.white,
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerLowest: t.surfaceSunken,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surfaceRaised,
      surfaceContainerHigh: t.surfaceRaised,
      surfaceContainerHighest: b == Brightness.dark ? AppColors.surface3 : const Color(0xFFF0EDE7),
      onSurfaceVariant: t.textMuted,
      outline: t.border,
      outlineVariant: t.border,
      error: t.danger,
      onError: Colors.white,
    );
    final base = ThemeData(useMaterial3: true, brightness: b, colorScheme: scheme, fontFamily: AppFonts.sans);
    TextStyle serif(double size, [FontWeight w = FontWeight.w600]) =>
        TextStyle(fontFamily: AppFonts.serif, fontSize: size, fontWeight: w, color: t.textPrimary, height: 1.2);
    final text = base.textTheme
        .apply(bodyColor: t.textPrimary, displayColor: t.textPrimary, fontFamily: AppFonts.sans)
        .copyWith(
          displaySmall: serif(34),
          headlineLarge: serif(30),
          headlineMedium: serif(26),
          headlineSmall: serif(21),
          titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: t.textPrimary),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.textPrimary),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textPrimary),
          bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: t.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: t.textPrimary),
          bodySmall: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
          labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.4),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textMuted, letterSpacing: 0.8),
        );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
    return base.copyWith(
      scaffoldBackgroundColor: t.canvas,
      textTheme: text,
      extensions: [t],
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(backgroundColor: t.canvas, foregroundColor: t.textPrimary, elevation: 0, scrolledUnderElevation: 0, titleTextStyle: serif(20)),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: t.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          elevation: 0,
          minimumSize: const Size(64, 40),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.border),
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentText,
          minimumSize: const Size(48, 40),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(40, 40), foregroundColor: t.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceSunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: t.danger),
        ),
        labelStyle: TextStyle(fontSize: 14, color: t.textMuted),
        hintStyle: TextStyle(fontSize: 14, color: t.textMuted),
        prefixIconColor: t.textMuted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: AppColors.gold.withValues(alpha: 0.18),
        side: BorderSide(color: t.border),
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        checkmarkColor: t.accentText,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.black),
        side: BorderSide(color: t.textMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.black : t.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : t.surfaceSunken),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: serif(21),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: t.border),
        ),
        textStyle: TextStyle(fontSize: 14, color: t.textPrimary),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surfaceRaised),
          side: WidgetStatePropertyAll(BorderSide(color: t.border)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: b == Brightness.dark ? AppColors.surface3 : const Color(0xFF1F1F22),
        contentTextStyle: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        width: 420,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: b == Brightness.dark ? AppColors.surface3 : const Color(0xFF1F1F22), borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: const TextStyle(fontFamily: AppFonts.sans, color: AppColors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textMuted,
        indicatorColor: AppColors.gold,
        dividerColor: t.border,
        labelStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontFamily: AppFonts.sans, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.gold, linearTrackColor: t.surfaceSunken),
      drawerTheme: DrawerThemeData(backgroundColor: t.surface, shape: const RoundedRectangleBorder()),
      listTileTheme: ListTileThemeData(iconColor: t.textMuted, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.accentText : t.textPrimary),
          side: WidgetStatePropertyAll(BorderSide(color: t.border)),
        ),
      ),
    );
  }
}
