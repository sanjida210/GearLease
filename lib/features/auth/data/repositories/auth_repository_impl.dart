import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/biometric_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final BiometricLocalDataSource biometricDataSource;
  final SecureStorageService storageService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.biometricDataSource,
    required this.storageService,
  });

  @override
  Future<Result<UserSession, Failure>> loginWithCredentials(
    String email,
    String password,
  ) async {
    try {
      final sessionModel = await remoteDataSource.login(email, password);
      await storageService.saveAuthToken(sessionModel.token);
      await storageService.saveActiveTenantId(sessionModel.organizationId);
      await storageService.setBiometricsEnabled(sessionModel.biometricsEnabled);
      await storageService.getOrCreateDeviceUuid();

      return Result.success(sessionModel);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserSession, Failure>> authenticateWithBiometrics() async {
    try {
      final authenticated = await biometricDataSource.authenticate(
        reason: 'Authenticate to access GearLease',
      );

      if (!authenticated) {
        return Result.failure(
          const BiometricFailure('Biometric authentication rejected or cancelled'),
        );
      }

      final token = await storageService.getAuthToken();
      if (token == null || token.isEmpty) {
        return Result.failure(
          const BiometricFailure('No active session found for biometric login'),
        );
      }

      final tenantId = await storageService.getActiveTenantId() ?? '';
      final deviceUuid = await storageService.getOrCreateDeviceUuid();
      final biometricsEnabled = await storageService.isBiometricsEnabled();

      final session = UserSession(
        userId: 'stored_user',
        email: 'authenticated_user',
        fullName: 'Authenticated User',
        organizationId: tenantId,
        role: UserRole.LESSEE_OWNER,
        deviceUuid: deviceUuid,
        biometricsEnabled: biometricsEnabled,
        token: token,
      );

      return Result.success(session);
    } on BiometricException catch (e) {
      return Result.failure(BiometricFailure(e.message));
    } catch (e) {
      return Result.failure(BiometricFailure(e.toString()));
    }
  }

  @override
  Future<Result<void, Failure>> logout() async {
    try {
      await storageService.clearAuth();
      return Result.success(null);
    } catch (e) {
      return Result.failure(CacheFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Result<UserSession?, Failure>> getActiveSession() async {
    try {
      final token = await storageService.getAuthToken();
      if (token == null || token.isEmpty) {
        return Result.success(null);
      }

      final tenantId = await storageService.getActiveTenantId() ?? '';
      final deviceUuid = await storageService.getOrCreateDeviceUuid();
      final biometricsEnabled = await storageService.isBiometricsEnabled();

      final session = UserSession(
        userId: 'active_user',
        email: 'active@gearlease.internal',
        fullName: 'Active User',
        organizationId: tenantId,
        role: UserRole.LESSEE_OWNER,
        deviceUuid: deviceUuid,
        biometricsEnabled: biometricsEnabled,
        token: token,
      );

      return Result.success(session);
    } catch (e) {
      return Result.failure(CacheFailure('Failed to get active session: ${e.toString()}'));
    }
  }
}
