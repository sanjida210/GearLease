import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/exceptions.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/storage/secure_storage_service.dart';
import 'package:gearlease/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gearlease/features/auth/data/datasources/biometric_local_datasource.dart';
import 'package:gearlease/features/auth/data/models/user_session_model.dart';
import 'package:gearlease/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gearlease/features/auth/domain/entities/user_session.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  late MockDio mockDio;
  late MockApiClient mockApiClient;
  late MockLocalAuthentication mockLocalAuth;
  late MockFlutterSecureStorage mockSecureStorage;
  late SecureStorageService secureStorageService;

  late AuthRemoteDataSource remoteDataSource;
  late BiometricLocalDataSource biometricDataSource;
  late AuthRepositoryImpl authRepository;

  final sampleJson = {
    'user_id': 'usr-101',
    'email': 'maya@roasters.com',
    'full_name': 'Maya Lin',
    'organization_id': 'org-craft-coffee',
    'role': 'LESSEE_OWNER',
    'device_uuid': 'dev-1234',
    'biometrics_enabled': true,
    'token': 'jwt-token-abc',
  };

  setUp(() {
    mockDio = MockDio();
    mockApiClient = MockApiClient();
    when(() => mockApiClient.dio).thenReturn(mockDio);

    mockLocalAuth = MockLocalAuthentication();
    mockSecureStorage = MockFlutterSecureStorage();
    secureStorageService = SecureStorageService(storage: mockSecureStorage);

    remoteDataSource = AuthRemoteDataSourceImpl(apiClient: mockApiClient);
    biometricDataSource = BiometricLocalDataSourceImpl(localAuth: mockLocalAuth);
    authRepository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      biometricDataSource: biometricDataSource,
      storageService: secureStorageService,
    );
  });

  group('UserSessionModel Tests', () {
    test('fromJson and toJson map correctly', () {
      final model = UserSessionModel.fromJson(sampleJson);

      expect(model.userId, 'usr-101');
      expect(model.email, 'maya@roasters.com');
      expect(model.fullName, 'Maya Lin');
      expect(model.organizationId, 'org-craft-coffee');
      expect(model.role, UserRole.LESSEE_OWNER);
      expect(model.token, 'jwt-token-abc');

      final json = model.toJson();
      expect(json['user_id'], 'usr-101');
      expect(json['role'], 'LESSEE_OWNER');
    });
  });

  group('AuthRemoteDataSource Tests', () {
    test('login posts credentials and returns UserSessionModel on 200', () async {
      when(() => mockDio.post(
            '/api/v1/auth/login',
            data: {'email': 'maya@roasters.com', 'password': 'password123'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            statusCode: 200,
            data: sampleJson,
          ));

      final result = await remoteDataSource.login('maya@roasters.com', 'password123');

      expect(result.userId, 'usr-101');
      expect(result.role, UserRole.LESSEE_OWNER);
    });

    test('login throws ServerException on non-200', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => remoteDataSource.login('bad@email.com', 'wrong'),
        throwsA(isA<ServerException>()),
      );
    });

    test('refreshToken posts token and returns updated token map', () async {
      when(() => mockDio.post(
            '/api/v1/auth/refresh',
            data: {'refresh_token': 'refresh-token-123'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
            statusCode: 200,
            data: {'token': 'new-jwt-token', 'refresh_token': 'new-refresh-token'},
          ));

      final result = await remoteDataSource.refreshToken('refresh-token-123');
      expect(result['token'], 'new-jwt-token');
    });
  });

  group('BiometricLocalDataSource Tests', () {
    test('isBiometricsAvailable checks sensor availability', () async {
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

      final available = await biometricDataSource.isBiometricsAvailable();
      expect(available, isTrue);
    });

    test('authenticate calls LocalAuthentication.authenticate', () async {
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => true);

      final success = await biometricDataSource.authenticate(
        reason: 'Authenticate to access GearLease',
      );
      expect(success, isTrue);
    });

    test('authenticate throws BiometricException when local auth fails', () async {
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenThrow(Exception('Sensor busy'));

      expect(
        () => biometricDataSource.authenticate(reason: 'Test'),
        throwsA(isA<BiometricException>()),
      );
    });
  });

  group('AuthRepositoryImpl Integration Tests', () {
    test('loginWithCredentials saves tokens and returns Result.success(UserSession)', () async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            statusCode: 200,
            data: sampleJson,
          ));
      when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => mockSecureStorage.read(key: 'device_uuid'))
          .thenAnswer((_) async => 'dev-1234');

      final result = await authRepository.loginWithCredentials('maya@roasters.com', 'password123');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.userId, 'usr-101');
      verify(() => mockSecureStorage.write(key: 'auth_token', value: 'jwt-token-abc')).called(1);
      verify(() => mockSecureStorage.write(key: 'active_tenant_id', value: 'org-craft-coffee')).called(1);
    });

    test('authenticateWithBiometrics succeeds when biometrics match and session exists', () async {
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => true);
      when(() => mockSecureStorage.read(key: 'auth_token'))
          .thenAnswer((_) async => 'jwt-token-abc');
      when(() => mockSecureStorage.read(key: 'active_tenant_id'))
          .thenAnswer((_) async => 'org-craft-coffee');
      when(() => mockSecureStorage.read(key: 'device_uuid'))
          .thenAnswer((_) async => 'dev-1234');
      when(() => mockSecureStorage.read(key: 'biometric_enabled'))
          .thenAnswer((_) async => 'true');

      final result = await authRepository.authenticateWithBiometrics();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.organizationId, 'org-craft-coffee');
    });

    test('authenticateWithBiometrics returns BiometricFailure when user cancels', () async {
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => false);

      final result = await authRepository.authenticateWithBiometrics();

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<BiometricFailure>());
    });

    test('logout clears secure storage and returns Result.success', () async {
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      final result = await authRepository.logout();

      expect(result.isSuccess, isTrue);
      verify(() => mockSecureStorage.delete(key: 'auth_token')).called(1);
      verify(() => mockSecureStorage.delete(key: 'active_tenant_id')).called(1);
    });

    test('getActiveSession returns session when auth_token exists', () async {
      when(() => mockSecureStorage.read(key: 'auth_token'))
          .thenAnswer((_) async => 'jwt-token-active');
      when(() => mockSecureStorage.read(key: 'active_tenant_id'))
          .thenAnswer((_) async => 'org-craft-coffee');
      when(() => mockSecureStorage.read(key: 'device_uuid'))
          .thenAnswer((_) async => 'dev-uuid-1');
      when(() => mockSecureStorage.read(key: 'biometric_enabled'))
          .thenAnswer((_) async => 'true');

      final result = await authRepository.getActiveSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.token, 'jwt-token-active');
      expect(result.dataOrNull?.organizationId, 'org-craft-coffee');
    });

    test('getActiveSession returns null when no auth_token exists', () async {
      when(() => mockSecureStorage.read(key: 'auth_token'))
          .thenAnswer((_) async => null);

      final result = await authRepository.getActiveSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });
  });
}
