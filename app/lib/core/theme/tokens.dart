import 'package:flutter/material.dart';

/// Design tokens — the single source for spacing, radii, elevation, motion
/// and breakpoints. Widgets must not hard-code these values.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double page = 20; // default horizontal page gutter (mobile)
}

class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get input => BorderRadius.circular(md);
  static BorderRadius get button => BorderRadius.circular(md);
}

class AppElevation {
  AppElevation._();
  static const double flat = 0;
  static const double raised = 1;
  static const double overlay = 3;
  static const double modal = 6;
}

class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve standard = Curves.easeOutCubic;
}

class AppBreakpoints {
  AppBreakpoints._();
  static const double compact = 600; // < 600: phone → bottom nav
  static const double medium = 900; // 600–900: tablet → compact rail
  static const double expanded = 1200; // >= 900: desktop → sidebar
  static const double feedMaxWidth = 680;
  static const double contentMaxWidth = 1120;
  static const double formMaxWidth = 460;
}

/// Minimum interactive size (WCAG / Material: 48dp).
const double kMinTapTarget = 48;
