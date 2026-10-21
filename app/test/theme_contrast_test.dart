import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/core/ui/ui.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  for (final (name, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    group('$name theme', () {
      final t = theme.extension<LuxTokens>()!;
      final bg = theme.scaffoldBackgroundColor;
      test('uses bundled serif headings and Inter body', () {
        expect(theme.textTheme.headlineMedium!.fontFamily, AppFonts.serif);
        expect(theme.textTheme.bodyLarge!.fontFamily, AppFonts.sans);
      });
      test('primary text passes AA (>= 4.5) on background and surface', () {
        expect(contrast(t.textPrimary, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(t.textPrimary, t.surface), greaterThanOrEqualTo(4.5));
      });
      test('muted text passes AA on background and surface', () {
        expect(contrast(t.textMuted, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(t.textMuted, t.surface), greaterThanOrEqualTo(4.5));
      });
      test('accent text passes AA on background', () {
        expect(contrast(t.accentText, bg), greaterThanOrEqualTo(4.5));
      });
      test('button label on gold passes AA', () {
        expect(contrast(AppColors.black, AppColors.gold), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
