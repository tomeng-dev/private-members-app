import 'package:dio/dio.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Returns either a full session map or `{requires2fa, needsSetup, preAuthToken}`.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await _api.raw.post('/auth/login', data: {'email': email, 'password': password});
      final data = res.data as Map<String, dynamic>;
      if (data['requiresTotp'] == true || data['requires2fa'] == true) {
        return data;
      }
      await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
      final roles = (data['user']['roles'] as List).map((e) => e.toString()).toList();
      if (!roles.contains('admin') && !roles.contains('super_admin') && !roles.contains('moderator')) {
        await _api.clearTokens();
        throw Failure('Staff role required');
      }
      return data;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> beginTotpSetup(String preAuthToken) async {
    try {
      final res = await _api.raw.post('/auth/2fa/setup', data: {'preAuthToken': preAuthToken});
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> confirmTotpSetup(String preAuthToken, String code) async {
    try {
      final res = await _api.raw.post('/auth/2fa/setup/confirm', data: {'preAuthToken': preAuthToken, 'code': code});
      final data = res.data as Map<String, dynamic>;
      await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
      return data;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> verifyTotp(String preAuthToken, String code) async {
    try {
      final res = await _api.raw.post('/auth/2fa/verify', data: {'preAuthToken': preAuthToken, 'code': code});
      final data = res.data as Map<String, dynamic>;
      await _api.saveTokens(access: data['accessToken'], refresh: data['refreshToken']);
      return data;
    } on DioException catch (e) {
      throw Failure(_msg(e), statusCode: e.response?.statusCode);
    }
  }

  Future<void> logout() async {
    try {
      final refresh = await _api.refreshToken;
      if (refresh != null) {
        await _api.raw.post('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {}
    await _api.clearTokens();
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Network error';
  }
}
