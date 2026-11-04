import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession?> getCurrentSession();
  Future<UserSession> loginWithCredentials(String email, String password);
  Future<bool> authenticateWithBiometrics();
  Future<void> logout();
}
