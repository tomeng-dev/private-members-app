import 'package:flutter_test/flutter_test.dart';
import 'package:member_app/features/auth/domain/entities/auth_session.dart';
import 'package:member_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:member_app/features/auth/domain/usecases/login_usecase.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<bool> hasSession() async => false;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    return AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      userId: '1',
      email: email,
      firstName: 'T',
      lastName: 'M',
      roles: const ['member'],
      foundingMember: false,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> resetPassword({required String token, required String password}) async {}

  @override
  Future<void> setPassword({required String token, required String password}) async {}
}

void main() {
  test('LoginUseCase returns session from repository', () async {
    final useCase = LoginUseCase(_FakeAuthRepo());
    final session = await useCase(email: 'a@b.com', password: 'x');
    expect(session.email, 'a@b.com');
    expect(session.roles, contains('member'));
  });
}
