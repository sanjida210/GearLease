import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/entities/quote_calculation.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_bloc.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_event.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_state.dart';
import 'package:gearlease/features/quote/presentation/screens/quote_calculator_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockQuoteBloc extends Mock implements QuoteBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockQuoteBloc mockQuoteBloc;

  const testAsset = HardwareAsset(
    id: 'ast-001',
    vendorId: 'vnd-101',
    serialNumber: 'LM-2026-9811',
    barcodePayload: 'GL-ROAST-2026-9811',
    barcodeSymbology: 'CODE_128',
    make: 'La Marzocco',
    model: 'Linea PB 3-Group',
    category: 'Commercial Espresso',
    initialValueCents: 2450000,
    iotDeviceIdentifier: 'IOT-LM-9811',
    currentConditionRating: 'GRADE_A',
  );

  const testQuote = QuoteCalculation(
    quoteId: 'qte_m_998822001',
    qualificationStatus: QualificationStatus.INSTANT_QUALIFIED,
    repaymentType: RepaymentStructureType.REVENUE_INDEXED,
    termMonths: 36,
    requestedAmountCents: 2450000,
    monthlyBaseCents: 75500,
    revenueSharePercent: 3.5,
    estimatedMonthlyCents: 72000,
    floorCents: 45000,
    capCents: 110000,
    expiresInSeconds: 900,
  );

  setUpAll(() {
    registerFallbackValue(const TermChanged(36));
    registerFallbackValue(const PricingModelSelected(PricingType.FIXED_ANNUITY));
    registerFallbackValue(const RepaymentStructureChanged(RepaymentStructureType.FIXED_MONTHLY));
  });

  setUp(() {
    mockQuoteBloc = MockQuoteBloc();
    when(() => mockQuoteBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(QuoteState state, {VoidCallback? onProceedToSignature}) {
    when(() => mockQuoteBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<QuoteBloc>.value(
        value: mockQuoteBloc,
        child: QuoteCalculatorScreen(
          onProceedToSignature: onProceedToSignature,
        ),
      ),
    );
  }

  group('Phase 15 — Interactive Quote Calculator Screen Widget Tests', () {
    testWidgets('renders QuoteLoading state with progress indicator', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(QuoteLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Requirement 1: Asset Spec Card shows make, model, serial, and MSRP badge', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      // Asset Spec Card is present
      expect(find.byKey(const Key('asset_spec_card')), findsOneWidget);
      expect(find.text('La Marzocco'), findsWidgets);
      expect(find.text('Linea PB 3-Group'), findsWidgets);
      expect(find.textContaining('LM-2026-9811'), findsOneWidget);

      // MSRP Badge
      expect(find.byKey(const Key('asset_msrp_badge')), findsOneWidget);
      expect(find.textContaining('\$24,500.00'), findsWidgets);
    });

    testWidgets('Requirement 2: Dynamic Underwriting Header shows "90-Second Fast-Track Decision" indicator badge', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      expect(find.byKey(const Key('fast_track_badge')), findsOneWidget);
      expect(find.text('90-Second Fast-Track Decision'), findsOneWidget);
      expect(find.text('INSTANT QUALIFIED'), findsOneWidget);
    });

    testWidgets('Requirement 3: Pricing Tier Switcher compares Fixed Annuity vs Revenue-Indexed vs IoT Pay-Per-Use', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      // All 3 tiers present
      expect(find.byKey(const Key('pricing_tier_fixed')), findsOneWidget);
      expect(find.byKey(const Key('pricing_tier_rev_indexed')), findsOneWidget);
      expect(find.byKey(const Key('pricing_tier_iot')), findsOneWidget);

      // Selecting IoT Pay-Per-Use dispatches event
      await tester.tap(find.byKey(const Key('pricing_tier_iot')));
      await tester.pump();

      verify(() => mockQuoteBloc.add(any(that: isA<PricingModelSelected>().having(
        (e) => e.type,
        'type',
        PricingType.PAY_PER_USE,
      )))).called(1);

      // Selecting Fixed Annuity dispatches event
      await tester.tap(find.byKey(const Key('pricing_tier_fixed')));
      await tester.pump();

      verify(() => mockQuoteBloc.add(any(that: isA<PricingModelSelected>().having(
        (e) => e.type,
        'type',
        PricingType.FIXED_ANNUITY,
      )))).called(1);
    });

    testWidgets('Requirement 4: Interactive Term Slider snaps to 36, 48, and 60 months', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      // Slider exists
      final sliderFinder = find.byKey(const Key('term_slider'));
      expect(sliderFinder, findsOneWidget);

      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, 36.0);
      expect(slider.max, 60.0);
      expect(slider.divisions, 2);

      // Test tapping chips for 48 Mo and 60 Mo
      await tester.tap(find.text('48 Mo'));
      await tester.pump();
      verify(() => mockQuoteBloc.add(const TermChanged(48))).called(1);

      await tester.tap(find.text('60 Mo'));
      await tester.pump();
      verify(() => mockQuoteBloc.add(const TermChanged(60))).called(1);

      // Test dragging the slider
      await tester.drag(sliderFinder, const Offset(150, 0));
      await tester.pump();
      verify(() => mockQuoteBloc.add(any(that: isA<TermChanged>()))).called(greaterThanOrEqualTo(1));
    });

    testWidgets('Requirement 5: Payment Summary Ledger displays monthly amount, rev share %, caps, and buyout options', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      expect(find.byKey(const Key('payment_summary_ledger')), findsOneWidget);
      // Base / Estimated Monthly Amount
      expect(find.textContaining('\$720.00'), findsWidgets);
      // Revenue Share %
      expect(find.textContaining('3.5%'), findsWidgets);
      // Payment Caps (Floor & Cap)
      expect(find.textContaining('\$450.00'), findsWidgets);
      expect(find.textContaining('\$1,100.00'), findsWidgets);
      // Buyout options
      expect(find.textContaining('FMV Buyout'), findsWidgets);
      expect(find.textContaining('\$1.00 Purchase Option'), findsWidgets);
    });

    testWidgets('Requirement 6: Bottom Persistent CTA triggers onProceedToSignature', (tester) async {
      bool proceedTriggered = false;

      await tester.pumpWidget(createWidgetUnderTest(
        const QuoteCalculatedState(
          asset: testAsset,
          calculation: testQuote,
          selectedTermMonths: 36,
          selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
        ),
        onProceedToSignature: () {
          proceedTriggered = true;
        },
      ));
      await tester.pump();

      final ctaFinder = find.byKey(const Key('quote_proceed_signature_button'));
      expect(ctaFinder, findsOneWidget);
      expect(find.text('Proceed to Customer Sign-on-Glass'), findsOneWidget);

      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pump();

      expect(proceedTriggered, isTrue);
    });
  });
}
