import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Console theme mode; dark by default, persisted per browser.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'admin_theme_mode';
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString(_key) == 'light') state = ThemeMode.light;
    } catch (_) {}
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, state == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
