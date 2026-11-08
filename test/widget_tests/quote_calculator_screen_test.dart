import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_bloc.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_event.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_state.dart';
import 'package:gearlease/features/quote/presentation/screens/quote_calculator_screen.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_bloc.dart';
import 'package:gearlease/features/signature/presentation/bloc/signature_state.dart';
import 'package:gearlease/features/signature/presentation/widgets/signature_pad_modal.dart';
import 'package:mocktail/mocktail.dart';

class MockQuoteBloc extends Mock implements QuoteBloc {}
class MockSignatureBloc extends Mock implements SignatureBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockQuoteBloc mockQuoteBloc;
  late MockSignatureBloc mockSignatureBloc;
  final List<MethodCall> hapticCalls = [];

  const testAsset = HardwareAsset(
    id: 'ast-cat-01',
    vendorId: 'vnd-101',
    serialNumber: 'CAT-320D-2026',
    barcodePayload: 'GL-CAT-2026',
    barcodeSymbology: 'CODE_128',
    make: 'Caterpillar',
    model: '320D Excavator',
    category: 'Heavy Earthmoving',
    initialValueCents: 24500000,
    iotDeviceIdentifier: 'IOT-CAT-01',
    currentConditionRating: 'GRADE_A',
  );

  const testQuote = QuoteCalculation(
    quoteId: 'qte_test_9988',
    qualificationStatus: QualificationStatus.INSTANT_QUALIFIED,
    repaymentType: RepaymentStructureType.REVENUE_INDEXED,
    termMonths: 36,
    requestedAmountCents: 24500000,
    monthlyBaseCents: 754000,
    revenueSharePercent: 3.5,
    estimatedMonthlyCents: 754000,
    floorCents: 500000,
    capCents: 1100000,
    expiresInSeconds: 900,
  );

  setUpAll(() {
    registerFallbackValue(const TermChanged(36));
    registerFallbackValue(const PricingModelSelected(PricingType.FIXED_ANNUITY));
  });

  setUp(() {
    mockQuoteBloc = MockQuoteBloc();
    mockSignatureBloc = MockSignatureBloc();
    when(() => mockQuoteBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockQuoteBloc.state).thenReturn(
      const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      ),
    );
    when(() => mockSignatureBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSignatureBloc.state).thenReturn(SignatureInitial());

    hapticCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method.startsWith('HapticFeedback.')) {
        hapticCalls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildCalculatorScreen({
    QuoteState? state,
    VoidCallback? onProceedToSignature,
  }) {
    when(() => mockQuoteBloc.state).thenReturn(
      state ??
          const QuoteCalculatedState(
            asset: testAsset,
            calculation: testQuote,
            selectedTermMonths: 36,
            selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
          ),
    );

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<QuoteBloc>.value(value: mockQuoteBloc),
          BlocProvider<SignatureBloc>.value(value: mockSignatureBloc),
        ],
        child: QuoteCalculatorScreen(
          onProceedToSignature: onProceedToSignature,
        ),
      ),
    );
  }

  group('Phase 29 — QuoteCalculatorScreen Widget & Interaction Tests', () {
    testWidgets('1. Pumps QuoteCalculatorScreen with pre-calculated quote data and renders specs', (tester) async {
      await tester.pumpWidget(buildCalculatorScreen());
      await tester.pumpAndSettle();

      // Asset Spec Card
      expect(find.byKey(const Key('asset_spec_card')), findsOneWidget);
      expect(find.text('Caterpillar'), findsWidgets);
      expect(find.text('320D Excavator'), findsWidgets);
      expect(find.textContaining('CAT-320D-2026'), findsOneWidget);

      // Fast-Track Decision Badge
      expect(find.byKey(const Key('fast_track_badge')), findsOneWidget);
      expect(find.text('INSTANT QUALIFIED'), findsOneWidget);

      // MSRP Badge & Formatted Amount
      expect(find.byKey(const Key('asset_msrp_badge')), findsOneWidget);
      expect(find.textContaining('\$245,000.00'), findsWidgets);

      // Payment Summary Ledger
      expect(find.byKey(const Key('payment_summary_ledger')), findsOneWidget);
      expect(find.textContaining('3.5%'), findsWidgets);
    });

    testWidgets('2. Slider gestures and chip taps trigger haptic callbacks and update UI term values', (tester) async {
      await tester.pumpWidget(buildCalculatorScreen());
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('term_slider'));
      expect(sliderFinder, findsOneWidget);

      // Verify slider divisions and bounds
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, 36.0);
      expect(slider.max, 60.0);
      expect(slider.divisions, 2);

      // Tap 48 Mo chip
      await tester.tap(find.text('48 Mo'));
      await tester.pump();

      // Verify HapticFeedback selection click was called
      expect(hapticCalls.any((call) => call.arguments == 'HapticFeedbackType.selectionClick'), isTrue);
      // Verify BLoC received TermChanged(48)
      verify(() => mockQuoteBloc.add(const TermChanged(48))).called(1);

      // Tap 60 Mo chip
      await tester.tap(find.text('60 Mo'));
      await tester.pump();

      verify(() => mockQuoteBloc.add(const TermChanged(60))).called(1);

      // Drag the slider
      await tester.drag(sliderFinder, const Offset(120, 0));
      await tester.pump();

      verify(() => mockQuoteBloc.add(any(that: isA<TermChanged>()))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('3. "Proceed to E-Sign" CTA button opens signature modal with canvas and guidance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<QuoteBloc>.value(value: mockQuoteBloc),
              BlocProvider<SignatureBloc>.value(value: mockSignatureBloc),
            ],
            child: Builder(
              builder: (context) {
                return QuoteCalculatorScreen(
                  onProceedToSignature: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BlocProvider<SignatureBloc>.value(
                        value: mockSignatureBloc,
                        child: const SignaturePadModal(
                          contractId: 'ctr-998822',
                          leaseId: 'ctr-998822',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.byKey(const Key('quote_proceed_signature_button'));
      expect(ctaFinder, findsOneWidget);

      // Scroll to CTA and tap
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      // Verify haptic feedback was triggered on CTA press
      expect(hapticCalls.any((call) => call.arguments == 'HapticFeedbackType.mediumImpact'), isTrue);

      // Verify Signature Modal is opened and displayed
      expect(find.byType(SignaturePadModal), findsOneWidget);
      expect(find.text('EXECUTE LEASE AGREEMENT'), findsOneWidget);
      expect(find.text('Contract ID: ctr-998822'), findsOneWidget);
      expect(find.byKey(const Key('signature_canvas_frame')), findsOneWidget);
    });
  });
}
