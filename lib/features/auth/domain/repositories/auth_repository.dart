import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<Result<UserSession, Failure>> loginWithCredentials(String email, String password);
  Future<Result<UserSession, Failure>> authenticateWithBiometrics();
  Future<Result<void, Failure>> logout();
  Future<Result<UserSession?, Failure>> getActiveSession();
}
