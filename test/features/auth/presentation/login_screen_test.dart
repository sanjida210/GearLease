import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/auth/domain/entities/user_session.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_event.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_state.dart';
import 'package:gearlease/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthBloc mockAuthBloc;

  const testSession = UserSession(
    userId: 'usr-101',
    email: 'operator@gearlease.com',
    fullName: 'Maya Lin',
    organizationId: 'org-craft-coffee',
    role: UserRole.LESSEE_OWNER,
    deviceUuid: 'dev-1234',
    biometricsEnabled: true,
    token: 'jwt-token-123',
  );

  setUpAll(() {
    registerFallbackValue(const LoginRequested('email', 'password'));
    registerFallbackValue(BiometricAuthRequested());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(AuthState state, {VoidCallback? onLoginSuccess}) {
    when(() => mockAuthBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: LoginScreen(onLoginSuccess: onLoginSuccess),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders all precision dark login elements and branding', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthInitial()));
      await tester.pump();

      expect(find.text('GEARLEASE'), findsOneWidget);
      expect(find.text('TLS 1.3 SECURE POS // VERIFIED NODE'), findsOneWidget);
      expect(find.byKey(const Key('role_preview_vendor')), findsOneWidget);
      expect(find.byKey(const Key('role_preview_lessee')), findsOneWidget);
      expect(find.byKey(const Key('login_org_selector')), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('login_biometric_button')), findsOneWidget);
      expect(find.text('Instant Biometric Login'), findsOneWidget);
    });

    testWidgets('toggles role indicator preview between Vendor POS and Fleet Owner', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthInitial()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('role_preview_lessee')));
      await tester.pump();

      expect(find.text('Fleet Owner'), findsOneWidget);

      await tester.tap(find.byKey(const Key('role_preview_vendor')));
      await tester.pump();

      expect(find.text('Vendor POS'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when state is AuthLoading', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('dispatches LoginRequested on valid submit tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(Unauthenticated()));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'operator@gearlease.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'pass1234');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      verify(() => mockAuthBloc.add(const LoginRequested(
            'operator@gearlease.com',
            'pass1234',
          ))).called(1);
    });

    testWidgets('dispatches BiometricAuthRequested on biometric button tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(Unauthenticated()));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('login_biometric_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login_biometric_button')));
      await tester.pump();

      verify(() => mockAuthBloc.add(any(that: isA<BiometricAuthRequested>()))).called(1);
    });

    testWidgets('displays inline error banner when state is AuthFailure', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const AuthFailure('Invalid credentials provided')));
      await tester.pump();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.text('Invalid credentials provided'), findsOneWidget);
    });

    testWidgets('triggers onLoginSuccess callback on Authenticated state', (tester) async {
      bool loginSucceeded = false;
      final streamController = StreamController<AuthState>.broadcast();
      addTearDown(streamController.close);

      when(() => mockAuthBloc.stream).thenAnswer((_) => streamController.stream);

      await tester.pumpWidget(createWidgetUnderTest(
        Unauthenticated(),
        onLoginSuccess: () => loginSucceeded = true,
      ));
      await tester.pump();

      streamController.add(const Authenticated(testSession));
      await tester.pump();

      expect(loginSucceeded, isTrue);
    });
  });
}
