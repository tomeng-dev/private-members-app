import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login({required String email, required String password});
  Future<void> logout();
  Future<void> forgotPassword(String email);
  Future<void> setPassword({required String token, required String password});
  Future<void> resetPassword({required String token, required String password});
  Future<bool> hasSession();
}
