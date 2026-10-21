class AppConfig {
  /// Override with --dart-define=API_BASE_URL=http://10.0.2.2:3000/api on Android emulator.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:3000/api');

  /// Build environment. Defaults to `production` so dev shortcuts are OFF
  /// unless a build explicitly passes --dart-define=APP_ENV=development.
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'production');

  /// Compile-time constant: when false, the compiler tree-shakes every
  /// dev-only widget/branch (quick login, dev badge) out of the binary.
  static const bool isDevelopment = appEnv == 'development';

  /// Dev-only demo password: pass the same value as api/.env DEV_DEFAULT_MEMBER_PASSWORD with
  /// --dart-define=DEV_MEMBER_PASSWORD=... No default is baked in. When empty, quick login only
  /// fills the email. Only read inside `if (AppConfig.isDevelopment)` branches.
  static const String devMemberPassword = String.fromEnvironment('DEV_MEMBER_PASSWORD');

  /// Socket.IO origin (no /api suffix). Defaults derived from apiBaseUrl.
  static String get socketOrigin {
    const override = String.fromEnvironment('SOCKET_ORIGIN', defaultValue: '');
    if (override.isNotEmpty) return override;
    final base = apiBaseUrl;
    if (base.endsWith('/api')) return base.substring(0, base.length - 4);
    return base;
  }
}
