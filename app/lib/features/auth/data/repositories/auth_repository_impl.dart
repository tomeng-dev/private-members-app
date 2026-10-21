import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    try {
      final res = await _api.raw.post('/auth/login', data: {'email': email, 'password': password});
      final data = res.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _api.saveTokens(access: data['accessToken'] as String, refresh: data['refreshToken'] as String);
      return AuthSession(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: user['id'] as String,
        email: user['email'] as String,
        firstName: user['firstName'] as String,
        lastName: user['lastName'] as String,
        roles: (user['roles'] as List).map((e) => e.toString()).toList(),
        foundingMember: user['foundingMember'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw Failure(_message(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refresh = await _api.refreshToken;
      if (refresh != null) {
        await _api.raw.post('/auth/logout', data: {'refreshToken': refresh});
      }
    } catch (_) {}
    await _api.clearTokens();
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _api.raw.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw Failure(_message(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<void> setPassword({required String token, required String password}) async {
    try {
      await _api.raw.post('/auth/set-password', data: {'token': token, 'password': password});
    } on DioException catch (e) {
      throw Failure(_message(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    try {
      await _api.raw.post('/auth/reset-password', data: {'token': token, 'password': password});
    } on DioException catch (e) {
      throw Failure(_message(e), statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<bool> hasSession() async {
    final t = await _storage.read(key: 'access_token');
    return t != null && t.isNotEmpty;
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is List) return m.join(', ');
      return m.toString();
    }
    return e.message ?? 'Network error';
  }
}
