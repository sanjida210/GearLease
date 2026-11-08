import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/auth/domain/entities/user_session.dart';
import 'package:gearlease/features/auth/domain/repositories/auth_repository.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_event.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;
  late AuthBloc authBloc;

  const testSession = UserSession(
    userId: 'usr-101',
    email: 'maya@roasters.com',
    fullName: 'Maya Lin',
    organizationId: 'org-craft-coffee',
    role: UserRole.LESSEE_OWNER,
    deviceUuid: 'dev-1234',
    biometricsEnabled: true,
    token: 'jwt-token-123',
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockAuthRepository);
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc Tests', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(AuthInitial()));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when AuthCheckRequested finds active session',
      build: () {
        when(() => mockAuthRepository.getActiveSession())
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        AuthLoading(),
        const AuthAuthenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when AuthCheckRequested finds no active session',
      build: () {
        when(() => mockAuthRepository.getActiveSession())
            .thenAnswer((_) async => Result.success(null));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [
        AuthLoading(),
        AuthUnauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful AuthLoginRequested',
      build: () {
        when(() => mockAuthRepository.loginWithCredentials('maya@roasters.com', 'password123'))
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        email: 'maya@roasters.com',
        password: 'password123',
      )),
      expect: () => [
        AuthLoading(),
        const AuthAuthenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailureState] on failed AuthLoginRequested',
      build: () {
        when(() => mockAuthRepository.loginWithCredentials(any(), any()))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Invalid credentials', statusCode: 401)));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        email: 'bad@roasters.com',
        password: 'wrong',
      )),
      expect: () => [
        AuthLoading(),
        const AuthFailureState('ServerFailure: Invalid credentials (Status: 401)'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful AuthBiometricLoginRequested',
      build: () {
        when(() => mockAuthRepository.authenticateWithBiometrics())
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthBiometricLoginRequested()),
      expect: () => [
        AuthLoading(),
        const AuthAuthenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailureState] on cancelled or failed AuthBiometricLoginRequested',
      build: () {
        when(() => mockAuthRepository.authenticateWithBiometrics())
            .thenAnswer((_) async => Result.failure(const BiometricFailure('User cancelled')));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthBiometricLoginRequested()),
      expect: () => [
        AuthLoading(),
        const AuthFailureState('BiometricFailure: User cancelled'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on AuthLogoutRequested',
      build: () {
        when(() => mockAuthRepository.logout())
            .thenAnswer((_) async => Result.success(null));
        return authBloc;
      },
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [
        AuthLoading(),
        AuthUnauthenticated(),
      ],
    );
  });
}
