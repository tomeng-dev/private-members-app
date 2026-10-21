class AppConfig {
  /// Override with --dart-define=API_BASE_URL=http://10.0.2.2:3000/api on Android emulator.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:3000/api');

  /// Build environment. Defaults to production so dev conveniences are
  /// compiled out unless explicitly enabled with --dart-define=APP_ENV=development.
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'production');
  static const bool isDevelopment = appEnv == 'development' || appEnv == 'dev';
}
