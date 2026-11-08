import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/signature/domain/entities/mobile_sign_event.dart';
import 'package:gearlease/features/signature/domain/entities/signature_payload_bundle.dart';
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
    auditHash: 'mock-sha256-hash',
  );

  final testPayloadBundle = SignaturePayloadBundle(
    leaseId: 'ctr-882201',
    agentId: 'usr-active-signer',
    hash: 'mock-sha256-hash',
    utcTimestampIso: '2026-11-04T10:30:00Z',
    strokeCount: 12,
    durationMs: 2500,
    platform: 'android',
    pngBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
    signatureSvg: '<svg></svg>',
    metadata: const {'hash': 'mock-sha256-hash', 'stroke_count': 12},
  );

  setUpAll(() {
    registerFallbackValue(SignatureCleared());
    registerFallbackValue(const SignatureSubmitted(
      contractId: 'ctr-882201',
      signatureSvg: '',
      requiresBiometricAudit: true,
    ));
  });

  setUp(() {
    mockSignatureBloc = MockSignatureBloc();
    when(() => mockSignatureBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(
    SignatureState state, {
    void Function(MobileSignEvent)? onSigned,
    void Function(SignaturePayloadBundle)? onPayloadBundleSigned,
    String? leaseId,
    String? agentId,
  }) {
    when(() => mockSignatureBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BlocProvider<SignatureBloc>.value(
          value: mockSignatureBloc,
          child: SignaturePadModal(
            contractId: 'ctr-882201',
            leaseId: leaseId ?? 'ctr-882201',
            agentId: agentId ?? 'usr-active-signer',
            onSigned: onSigned,
            onPayloadBundleSigned: onPayloadBundleSigned,
          ),
        ),
      ),
    );
  }

  group('Phase 16 — On-Glass Vector Signature Capture & Audit Trail Widget Tests', () {
    testWidgets('Requirement 1: Modal sheet with landscape canvas renders correctly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(SignatureInitial()));
      await tester.pump();

      expect(find.text('EXECUTE LEASE AGREEMENT'), findsOneWidget);
      expect(find.text('Contract ID: ctr-882201'), findsOneWidget);

      // Landscape canvas frame exists
      final frameFinder = find.byKey(const Key('signature_canvas_frame'));
      expect(frameFinder, findsOneWidget);

      // Verify guidance text
      expect(find.text('Sign within the frame using your finger or stylus'), findsOneWidget);
    });

    testWidgets('Requirement 2: Clear and Save controls with stroke telemetry indicator HUD', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SignatureDrawing(14)));
      await tester.pump();

      expect(find.byKey(const Key('signature_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('signature_submit_button')), findsOneWidget);

      // Telemetry HUD shows stroke metrics
      final hudFinder = find.byKey(const Key('signature_telemetry_hud'));
      expect(hudFinder, findsOneWidget);
      expect(find.textContaining('pts'), findsWidgets);

      // Tap Clear dispatches SignatureCleared
      await tester.tap(find.byKey(const Key('signature_clear_button')));
      await tester.pump();

      verify(() => mockSignatureBloc.add(any(that: isA<SignatureCleared>()))).called(1);
    });

    testWidgets('Requirement 4: Biometric confirmation indicator before final submission', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(SignatureInitial()));
      await tester.pump();

      // Biometric audit badge / prompt indicator is rendered
      expect(find.byKey(const Key('biometric_confirmation_badge')), findsOneWidget);
      expect(find.textContaining('Biometric'), findsWidgets);
    });

    testWidgets('Requirement 3 & 4: Cryptographic audit generation dispatches SignatureSubmitted with biometric audit and hash bundle', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SignatureDrawing(5)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('signature_submit_button')));
      await tester.pump();

      verify(() => mockSignatureBloc.add(any(that: isA<SignatureSubmitted>().having(
            (e) => e.requiresBiometricAudit,
            'requiresBiometricAudit',
            isTrue,
          )))).called(1);
    });

    testWidgets('Requirement 5: Returns signed signature payload bundle to parent quote workflow', (tester) async {
      MobileSignEvent? completedSignEvent;
      SignaturePayloadBundle? completedBundle;

      when(() => mockSignatureBloc.state).thenReturn(SignatureSuccess(
        testSignEvent,
        payloadBundle: testPayloadBundle,
      ));

      await tester.pumpWidget(createWidgetUnderTest(
        SignatureSuccess(testSignEvent, payloadBundle: testPayloadBundle),
        onSigned: (event) => completedSignEvent = event,
        onPayloadBundleSigned: (bundle) => completedBundle = bundle,
      ));
      await tester.pump();

      expect(completedSignEvent?.contractId, 'ctr-882201');
      expect(completedBundle?.leaseId, 'ctr-882201');
      expect(completedBundle?.hash, 'mock-sha256-hash');
      expect(completedBundle?.strokeCount, 12);
    });
  });
}
