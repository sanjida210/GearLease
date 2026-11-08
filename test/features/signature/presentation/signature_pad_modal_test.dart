import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/signature/domain/entities/mobile_sign_event.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_bloc.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_event.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_state.dart';
import 'package:gearlease/features/signature/presentation/widgets/signature_pad_modal.dart';
import 'package:mocktail/mocktail.dart';

class MockSignatureBloc extends Mock implements SignatureBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSignatureBloc mockSignatureBloc;

  final testSignEvent = MobileSignEvent(
    id: 'sgn-001',
    contractId: 'ctr-882201',
    signerUserId: 'usr-101',
    biometricUsed: 'FACE_ID',
    signatureVectorPath: 'M10 20 L30 40',
    signerIp: '127.0.0.1',
    gpsLatitude: 37.77,
    gpsLongitude: -122.41,
    signedAt: DateTime.parse('2026-11-04T10:30:00Z'),
  );

  setUpAll(() {
    registerFallbackValue(SignatureCleared());
    registerFallbackValue(const SignatureSubmitted(
      contractId: 'ctr-882201',
      signatureSvg: '',
    ));
  });

  setUp(() {
    mockSignatureBloc = MockSignatureBloc();
    when(() => mockSignatureBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(SignatureState state) {
    when(() => mockSignatureBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BlocProvider<SignatureBloc>.value(
          value: mockSignatureBloc,
          child: const SignaturePadModal(
            contractId: 'ctr-882201',
          ),
        ),
      ),
    );
  }

  group('SignaturePadModal Widget Tests', () {
    testWidgets('renders vector signature pad, clear button, and submit CTA', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(SignatureInitial()));
      await tester.pump();

      expect(find.text('EXECUTE LEASE AGREEMENT'), findsOneWidget);
      expect(find.byKey(const Key('signature_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('signature_submit_button')), findsOneWidget);
    });

    testWidgets('taps clear button and dispatches SignatureCleared', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SignatureDrawing(8)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('signature_clear_button')));
      await tester.pump();

      verify(() => mockSignatureBloc.add(any(that: isA<SignatureCleared>()))).called(1);
    });

    testWidgets('shows CircularProgressIndicator when state is SignatureSubmitting', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(SignatureSubmitting()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('triggers onSigned callback on SignatureSuccess', (tester) async {
      MobileSignEvent? completed;
      when(() => mockSignatureBloc.state).thenReturn(SignatureSuccess(testSignEvent));

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BlocProvider<SignatureBloc>.value(
            value: mockSignatureBloc,
            child: SignaturePadModal(
              contractId: 'ctr-882201',
              onSigned: (event) => completed = event,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(completed?.contractId, 'ctr-882201');
    });
  });
}
