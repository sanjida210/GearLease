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
    fixedMonthlyCents: 75500,
    revenueSharePct: 3.5,
    estimatedMonthlyCents: 72000,
    floorCents: 45000,
    capCents: 110000,
    expiresInSeconds: 900,
  );

  setUpAll(() {
    registerFallbackValue(const TermChanged(36));
    registerFallbackValue(const RepaymentStructureChanged(RepaymentStructureType.FIXED_MONTHLY));
  });

  setUp(() {
    mockQuoteBloc = MockQuoteBloc();
    when(() => mockQuoteBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(QuoteState state) {
    when(() => mockQuoteBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<QuoteBloc>.value(
        value: mockQuoteBloc,
        child: const QuoteCalculatorScreen(),
      ),
    );
  }

  group('QuoteCalculatorScreen Widget Tests', () {
    testWidgets('renders QuoteLoading state', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(QuoteLoading()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders calculated quote with asset and repayment options', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      expect(find.text('La Marzocco Linea PB 3-Group'), findsOneWidget);
      expect(find.text('INSTANT QUALIFIED'), findsOneWidget);
      expect(find.text('36 Mo'), findsOneWidget);
      expect(find.text('48 Mo'), findsOneWidget);
      expect(find.text('60 Mo'), findsOneWidget);
      expect(find.byKey(const Key('quote_proceed_signature_button')), findsOneWidget);
    });

    testWidgets('dispatches TermChanged when tapping 48 Mo', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      await tester.tap(find.text('48 Mo'));
      await tester.pump();

      verify(() => mockQuoteBloc.add(const TermChanged(48))).called(1);
    });

    testWidgets('dispatches RepaymentStructureChanged when switching pricing model', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const QuoteCalculatedState(
        asset: testAsset,
        calculation: testQuote,
        selectedTermMonths: 36,
        selectedStructure: RepaymentStructureType.REVENUE_INDEXED,
      )));
      await tester.pump();

      await tester.tap(find.text('Fixed Monthly'));
      await tester.pump();

      verify(() => mockQuoteBloc.add(
            const RepaymentStructureChanged(RepaymentStructureType.FIXED_MONTHLY),
          )).called(1);
    });
  });
}
