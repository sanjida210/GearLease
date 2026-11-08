import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart' hide AuthFailure;
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
      'emits [AuthLoading, Authenticated] when AppStarted finds active session',
      build: () {
        when(() => mockAuthRepository.getActiveSession())
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(AppStarted()),
      expect: () => [
        AuthLoading(),
        const Authenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] when AppStarted finds no active session',
      build: () {
        when(() => mockAuthRepository.getActiveSession())
            .thenAnswer((_) async => Result.success(null));
        return authBloc;
      },
      act: (bloc) => bloc.add(AppStarted()),
      expect: () => [
        AuthLoading(),
        Unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] on successful LoginRequested',
      build: () {
        when(() => mockAuthRepository.loginWithCredentials('maya@roasters.com', 'password123'))
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(
        'maya@roasters.com',
        'password123',
      )),
      expect: () => [
        AuthLoading(),
        const Authenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] on failed LoginRequested',
      build: () {
        when(() => mockAuthRepository.loginWithCredentials(any(), any()))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Invalid credentials', statusCode: 401)));
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(
        'bad@roasters.com',
        'wrong',
      )),
      expect: () => [
        AuthLoading(),
        const AuthFailure('ServerFailure: Invalid credentials (Status: 401)'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Authenticated] on successful BiometricAuthRequested',
      build: () {
        when(() => mockAuthRepository.authenticateWithBiometrics())
            .thenAnswer((_) async => Result.success(testSession));
        return authBloc;
      },
      act: (bloc) => bloc.add(BiometricAuthRequested()),
      expect: () => [
        AuthLoading(),
        const Authenticated(testSession),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] on cancelled or failed BiometricAuthRequested',
      build: () {
        when(() => mockAuthRepository.authenticateWithBiometrics())
            .thenAnswer((_) async => Result.failure(const BiometricFailure('User cancelled')));
        return authBloc;
      },
      act: (bloc) => bloc.add(BiometricAuthRequested()),
      expect: () => [
        AuthLoading(),
        const AuthFailure('BiometricFailure: User cancelled'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, Unauthenticated] on LogoutRequested',
      build: () {
        when(() => mockAuthRepository.logout())
            .thenAnswer((_) async => Result.success(null));
        return authBloc;
      },
      act: (bloc) => bloc.add(LogoutRequested()),
      expect: () => [
        AuthLoading(),
        Unauthenticated(),
      ],
    );
  });
}
