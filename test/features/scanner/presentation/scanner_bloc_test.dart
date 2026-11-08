import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/error/failures.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';
import 'package:gearlease/features/quote/domain/usecases/get_asset_by_barcode_usecase.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_bloc.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_event.dart';
import 'package:gearlease/features/scanner/presentation/bloc/scanner_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAssetByBarcodeUseCase extends Mock implements GetAssetByBarcodeUseCase {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGetAssetByBarcodeUseCase mockGetAssetUseCase;
  late ScannerBloc scannerBloc;

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

  setUp(() {
    mockGetAssetUseCase = MockGetAssetByBarcodeUseCase();
    scannerBloc = ScannerBloc(getAssetByBarcodeUseCase: mockGetAssetUseCase);
  });

  tearDown(() {
    scannerBloc.close();
  });

  group('ScannerBloc Tests', () {
    test('initial state is ScannerInitial', () {
      expect(scannerBloc.state, equals(ScannerInitial()));
    });

    blocTest<ScannerBloc, ScannerState>(
      'emits ScannerActive on ScannerStartRequested',
      build: () => scannerBloc,
      act: (bloc) => bloc.add(ScannerStartRequested()),
      expect: () => [
        const ScannerActive(isTorchOn: false),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'toggles torch state on ScannerTorchToggled',
      build: () => scannerBloc,
      seed: () => const ScannerActive(isTorchOn: false),
      act: (bloc) => bloc.add(ScannerTorchToggled()),
      expect: () => [
        const ScannerActive(isTorchOn: true),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [ScannerProcessing, ScannerSuccess] on valid barcode resolution',
      build: () {
        when(() => mockGetAssetUseCase('GL-ROAST-2026-9811'))
            .thenAnswer((_) async => Result.success(testAsset));
        return scannerBloc;
      },
      act: (bloc) => bloc.add(const ScannerBarcodeDetected('GL-ROAST-2026-9811')),
      expect: () => [
        const ScannerProcessing('GL-ROAST-2026-9811'),
        const ScannerSuccess(testAsset),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits [ScannerProcessing, ScannerFailureState] on failed barcode lookup',
      build: () {
        when(() => mockGetAssetUseCase('UNKNOWN'))
            .thenAnswer((_) async => Result.failure(const ServerFailure('Asset not recognized')));
        return scannerBloc;
      },
      act: (bloc) => bloc.add(const ScannerBarcodeDetected('UNKNOWN')),
      expect: () => [
        const ScannerProcessing('UNKNOWN'),
        const ScannerFailureState('ServerFailure: Asset not recognized'),
      ],
    );

    blocTest<ScannerBloc, ScannerState>(
      'emits ScannerInitial on ScannerReset',
      build: () => scannerBloc,
      seed: () => const ScannerSuccess(testAsset),
      act: (bloc) => bloc.add(ScannerReset()),
      expect: () => [
        ScannerInitial(),
      ],
    );
  });
}
