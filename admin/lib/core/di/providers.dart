import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/admin/data/admin_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(baseUrl: AppConfig.apiBaseUrl));
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));

class AdminSessionNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoggedIn(bool value) => state = value;
}

/// Signed-in staff profile (name, email, roles) for the top-bar profile menu.
/// Non-secret; cached in shared_preferences so a browser refresh keeps it.
class StaffUserNotifier extends Notifier<Map<String, dynamic>?> {
  static const _key = 'admin_staff_user';
  @override
  Map<String, dynamic>? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null && state == null) state = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}
  }

  Future<void> set(Map<String, dynamic>? user) async {
    state = user == null
        ? null
        : {
            for (final k in ['id', 'email', 'firstName', 'lastName', 'roles']) k: user[k],
          };
    try {
      final p = await SharedPreferences.getInstance();
      state == null ? await p.remove(_key) : await p.setString(_key, jsonEncode(state));
    } catch (_) {}
  }
}

final staffUserProvider = NotifierProvider<StaffUserNotifier, Map<String, dynamic>?>(StaffUserNotifier.new);

/// DEV / STAGING / PROD label from the API (falls back to DEV when unreachable).
final environmentProvider = FutureProvider<String>((ref) async {
  try {
    return await ref.read(adminRepositoryProvider).consoleEnv();
  } catch (_) {
    return 'DEV';
  }
});

final adminSessionProvider = NotifierProvider<AdminSessionNotifier, bool>(AdminSessionNotifier.new);
