import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/auth/domain/entities/user_session.dart';
import 'package:gearlease/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('UserSession Entity Tests', () {
    const session1 = UserSession(
      userId: 'usr-101',
      email: 'maya@roasters.com',
      fullName: 'Maya Lin',
      organizationId: 'org-craft-coffee',
      role: UserRole.LESSEE_OWNER,
      deviceUuid: 'dev-iphone-15',
      biometricsEnabled: true,
      token: 'jwt-access-token-xyz',
    );

    const session2 = UserSession(
      userId: 'usr-101',
      email: 'maya@roasters.com',
      fullName: 'Maya Lin',
      organizationId: 'org-craft-coffee',
      role: UserRole.LESSEE_OWNER,
      deviceUuid: 'dev-iphone-15',
      biometricsEnabled: true,
      token: 'jwt-access-token-xyz',
    );

    const sessionDifferent = UserSession(
      userId: 'usr-202',
      email: 'dave@machinery.com',
      fullName: 'Dealer Dave',
      organizationId: 'org-dealers-nw',
      role: UserRole.VENDOR_AGENT,
      deviceUuid: 'dev-ipad-pro',
      biometricsEnabled: false,
      token: 'jwt-access-token-abc',
    );

    test('supports value equality via Equatable', () {
      expect(session1, equals(session2));
      expect(session1, isNot(equals(sessionDifferent)));
      expect(session1.props, [
        'usr-101',
        'maya@roasters.com',
        'Maya Lin',
        'org-craft-coffee',
        UserRole.LESSEE_OWNER,
        'dev-iphone-15',
        true,
        'jwt-access-token-xyz',
      ]);
    });

    test('UserRole enum contains LESSEE_OWNER and VENDOR_AGENT', () {
      expect(UserRole.values, contains(UserRole.LESSEE_OWNER));
      expect(UserRole.values, contains(UserRole.VENDOR_AGENT));
    });

    test('copyWith updates specified fields immutably', () {
      final updated = session1.copyWith(
        biometricsEnabled: false,
        token: 'new-token-999',
      );

      expect(updated.biometricsEnabled, isFalse);
      expect(updated.token, 'new-token-999');
      expect(updated.userId, session1.userId);
      expect(updated.fullName, session1.fullName);
    });
  });

  group('AuthRepository Contract Tests', () {
    late MockAuthRepository mockAuthRepository;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
    });

    const mockSession = UserSession(
      userId: 'usr-101',
      email: 'maya@roasters.com',
      fullName: 'Maya Lin',
      organizationId: 'org-craft-coffee',
      role: UserRole.LESSEE_OWNER,
      deviceUuid: 'dev-iphone-15',
      biometricsEnabled: true,
      token: 'jwt-access-token-xyz',
    );

    test('loginWithCredentials returns Result.success(UserSession)', () async {
      when(() => mockAuthRepository.loginWithCredentials('maya@roasters.com', 'secret123'))
          .thenAnswer((_) async => Result.success(mockSession));

      final result = await mockAuthRepository.loginWithCredentials('maya@roasters.com', 'secret123');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(mockSession));
    });

    test('loginWithCredentials returns Result.failure(AuthFailure)', () async {
      when(() => mockAuthRepository.loginWithCredentials('bad@email.com', 'wrong'))
          .thenAnswer((_) async => Result.failure(const AuthFailure('Invalid credentials')));

      final result = await mockAuthRepository.loginWithCredentials('bad@email.com', 'wrong');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('authenticateWithBiometrics returns Result.success(UserSession)', () async {
      when(() => mockAuthRepository.authenticateWithBiometrics())
          .thenAnswer((_) async => Result.success(mockSession));

      final result = await mockAuthRepository.authenticateWithBiometrics();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(mockSession));
    });

    test('logout returns Result.success(null)', () async {
      when(() => mockAuthRepository.logout())
          .thenAnswer((_) async => Result.success(null));

      final result = await mockAuthRepository.logout();

      expect(result.isSuccess, isTrue);
    });

    test('getActiveSession returns Result.success(UserSession?)', () async {
      when(() => mockAuthRepository.getActiveSession())
          .thenAnswer((_) async => Result.success(mockSession));

      final result = await mockAuthRepository.getActiveSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(mockSession));
    });
  });
}
