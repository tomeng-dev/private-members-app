import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repo);
  final AuthRepository _repo;

  Future<AuthSession> call({required String email, required String password}) {
    return _repo.login(email: email, password: password);
  }
}
