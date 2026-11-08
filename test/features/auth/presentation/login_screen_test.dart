import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_event.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_state.dart';
import 'package:gearlease/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(const AuthLoginRequested(email: '', password: ''));
    registerFallbackValue(AuthBiometricLoginRequested());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(AuthState state) {
    when(() => mockAuthBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('renders all login elements correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthInitial()));
      await tester.pump();

      expect(find.text('GEARLEASE'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('login_biometric_button')), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when state is AuthLoading', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('dispatches AuthLoginRequested on valid submit tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthUnauthenticated()));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'operator@gearlease.com');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'pass1234');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthLoginRequested(
            email: 'operator@gearlease.com',
            password: 'pass1234',
          ))).called(1);
    });

    testWidgets('dispatches AuthBiometricLoginRequested on biometric button tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AuthUnauthenticated()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('login_biometric_button')));
      await tester.pump();

      verify(() => mockAuthBloc.add(any(that: isA<AuthBiometricLoginRequested>()))).called(1);
    });
  });
}
