import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_event.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_state.dart';
import 'package:gearlease/features/scanner/presentation/screens/barcode_scanner_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockScannerBloc extends Mock implements ScannerBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockScannerBloc mockScannerBloc;

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

  setUpAll(() {
    registerFallbackValue(ScannerTorchToggled());
    registerFallbackValue(const ScannerBarcodeDetected(''));
  });

  setUp(() {
    mockScannerBloc = MockScannerBloc();
    when(() => mockScannerBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(ScannerState state) {
    when(() => mockScannerBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<ScannerBloc>.value(
        value: mockScannerBloc,
        child: const BarcodeScannerScreen(),
      ),
    );
  }

  group('BarcodeScannerScreen Widget Tests', () {
    testWidgets('renders HUD elements, torch button, and manual entry button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const ScannerActive(isTorchOn: false)));
      await tester.pump();

      expect(find.text('OPTICAL ASSET SCANNER'), findsOneWidget);
      expect(find.byKey(const Key('scanner_torch_button')), findsOneWidget);
      expect(find.byKey(const Key('scanner_manual_entry_button')), findsOneWidget);
    });

    testWidgets('taps torch button and dispatches ScannerTorchToggled', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const ScannerActive(isTorchOn: false)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('scanner_torch_button')));
      await tester.pump();

      verify(() => mockScannerBloc.add(any(that: isA<ScannerTorchToggled>()))).called(1);
    });

    testWidgets('shows manual input dialog and dispatches ScannerBarcodeDetected', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const ScannerActive(isTorchOn: false)));
      await tester.pump();

      await tester.tap(find.byKey(const Key('scanner_manual_entry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manual_barcode_input')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('manual_barcode_input')), 'GL-ROAST-2026-9811');
      await tester.tap(find.byKey(const Key('manual_resolve_button')));
      await tester.pumpAndSettle();

      verify(() => mockScannerBloc.add(const ScannerBarcodeDetected('GL-ROAST-2026-9811'))).called(1);
    });

    testWidgets('renders CircularProgressIndicator when state is ScannerProcessing', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const ScannerProcessing('GL-ROAST-2026-9811')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('invokes onAssetResolved when state is ScannerSuccess', (tester) async {
      HardwareAsset? resolved;
      when(() => mockScannerBloc.state).thenReturn(const ScannerSuccess(testAsset));

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: BlocProvider<ScannerBloc>.value(
          value: mockScannerBloc,
          child: BarcodeScannerScreen(
            onAssetResolved: (asset) => resolved = asset,
          ),
        ),
      ));
      await tester.pump();

      expect(resolved?.serialNumber, 'LM-2026-9811');
    });
  });
}
