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
import 'package:signature/signature.dart' hide SignatureState;

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
    signedAt: DateTime.parse('2026-11-09T00:00:00Z'),
    auditHash: 'a' * 64,
  );

  final testPayloadBundle = SignaturePayloadBundle(
    leaseId: 'ctr-882201',
    agentId: 'usr-active-signer',
    hash: 'a' * 64,
    utcTimestampIso: '2026-11-09T00:00:00Z',
    strokeCount: 15,
    durationMs: 1200,
    platform: 'android',
    pngBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    signatureSvg: '<svg></svg>',
    metadata: const {'hash': 'mock-hash', 'stroke_count': 15},
  );

  setUpAll(() {
    registerFallbackValue(SignatureCleared());
    registerFallbackValue(const SignatureStrokeAdded(1));
    registerFallbackValue(const SignatureSubmitted(
      contractId: 'ctr-882201',
      signatureSvg: '',
      requiresBiometricAudit: true,
    ));
  });

  setUp(() {
    mockSignatureBloc = MockSignatureBloc();
    when(() => mockSignatureBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSignatureBloc.state).thenReturn(SignatureInitial());
  });

  Widget buildSignatureModal({
    SignatureState? state,
    void Function(MobileSignEvent)? onSigned,
    void Function(SignaturePayloadBundle)? onPayloadBundleSigned,
  }) {
    if (state != null) {
      when(() => mockSignatureBloc.state).thenReturn(state);
    }

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BlocProvider<SignatureBloc>.value(
          value: mockSignatureBloc,
          child: SignaturePadModal(
            contractId: 'ctr-882201',
            leaseId: 'ctr-882201',
            agentId: 'usr-active-signer',
            onSigned: onSigned,
            onPayloadBundleSigned: onPayloadBundleSigned,
            requiresBiometricAudit: true,
          ),
        ),
      ),
    );
  }

  group('Phase 29 — SignaturePadModal Widget & Interaction Tests', () {
    testWidgets('1. Renders SignaturePadModal canvas frame, buttons, and biometric audit indicators', (tester) async {
      await tester.pumpWidget(buildSignatureModal());
      await tester.pumpAndSettle();

      // Title & Contract ID
      expect(find.text('EXECUTE LEASE AGREEMENT'), findsOneWidget);
      expect(find.text('Contract ID: ctr-882201'), findsOneWidget);

      // Signature Canvas Frame
      expect(find.byKey(const Key('signature_canvas_frame')), findsOneWidget);
      expect(find.byType(Signature), findsOneWidget);

      // Buttons
      expect(find.byKey(const Key('signature_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('signature_submit_button')), findsOneWidget);

      // Biometric Audit Badge
      expect(find.byKey(const Key('biometric_confirmation_badge')), findsOneWidget);
      expect(find.textContaining('Biometric'), findsWidgets);
    });

    testWidgets('2. Simulates stroke gestures on the canvas and verifies event telemetry HUD updates', (tester) async {
      await tester.pumpWidget(buildSignatureModal(state: const SignatureDrawing(10)));
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(Signature);
      expect(canvasFinder, findsOneWidget);

      // Simulate drawing gestures on canvas: touch down -> drag -> touch up
      await tester.drag(canvasFinder, const Offset(80, 40));
      await tester.pump();
      await tester.drag(canvasFinder, const Offset(-40, 60));
      await tester.pump();

      // Verify BLoC received stroke events
      verify(() => mockSignatureBloc.add(any(that: isA<SignatureStrokeAdded>()))).called(greaterThanOrEqualTo(1));

      // Telemetry HUD shows stroke point metrics
      expect(find.byKey(const Key('signature_telemetry_hud')), findsOneWidget);
      expect(find.textContaining('pts'), findsWidgets);
    });

    testWidgets('3. Verifies "Save" generates SHA-256 hash metadata, dispatches SignatureSubmitted, and emits payload bundle', (tester) async {
      await tester.pumpWidget(buildSignatureModal(
        state: const SignatureDrawing(20),
      ));
      await tester.pumpAndSettle();

      // Draw stroke first
      await tester.drag(find.byType(Signature), const Offset(100, 30));
      await tester.pump();

      // Tap "Save & Authenticate" / Submit button
      final submitFinder = find.byKey(const Key('signature_submit_button'));
      await tester.tap(submitFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Capture and verify SignatureSubmitted event
      final captured = verify(() => mockSignatureBloc.add(captureAny(
            that: isA<SignatureSubmitted>(),
          ))).captured;

      expect(captured.isNotEmpty, isTrue);
      final submittedEvent = captured.first as SignatureSubmitted;

      // Verify SHA-256 hash generation (64 hex characters)
      final bundle = submittedEvent.payloadBundle;
      expect(bundle, isNotNull);
      expect(bundle?.hash.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(bundle!.hash), isTrue);
      expect(bundle.leaseId, equals('ctr-882201'));
      expect(bundle.agentId, equals('usr-active-signer'));
      expect(bundle.metadata['hash'], equals(bundle.hash));
      expect(bundle.metadata.containsKey('timestamp'), isTrue);
      expect(bundle.metadata.containsKey('stroke_count'), isTrue);
    });

    testWidgets('4. "Clear" button resets canvas and dispatches SignatureCleared event', (tester) async {
      await tester.pumpWidget(buildSignatureModal(state: const SignatureDrawing(8)));
      await tester.pumpAndSettle();

      final clearFinder = find.byKey(const Key('signature_clear_button'));
      await tester.tap(clearFinder);
      await tester.pump();

      verify(() => mockSignatureBloc.add(any(that: isA<SignatureCleared>()))).called(1);
    });

    testWidgets('5. Emits result when SignatureSuccess with payloadBundle is set on the modal', (tester) async {
      MobileSignEvent? completedSignEvent;
      SignaturePayloadBundle? completedBundle;

      await tester.pumpWidget(buildSignatureModal(
        state: SignatureSuccess(testSignEvent, payloadBundle: testPayloadBundle),
        onSigned: (event) => completedSignEvent = event,
        onPayloadBundleSigned: (bundle) => completedBundle = bundle,
      ));
      await tester.pumpAndSettle();

      expect(completedSignEvent?.contractId, equals('ctr-882201'));
      expect(completedBundle?.leaseId, equals('ctr-882201'));
      expect(completedBundle?.hash, equals('a' * 64));
      expect(completedBundle?.strokeCount, equals(15));
    });
  });
}
