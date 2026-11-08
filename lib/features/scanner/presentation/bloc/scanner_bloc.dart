import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gearlease/features/quote/domain/usecases/get_asset_by_barcode_usecase.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final GetAssetByBarcodeUseCase getAssetByBarcodeUseCase;

  bool _isTorchOn = false;

  ScannerBloc({required this.getAssetByBarcodeUseCase}) : super(ScannerInitial()) {
    on<ScannerStartRequested>(_onScannerStartRequested);
    on<ScannerTorchToggled>(_onScannerTorchToggled);
    on<ScannerBarcodeDetected>(_onScannerBarcodeDetected);
    on<ScannerReset>(_onScannerReset);
  }

  void _onScannerStartRequested(
    ScannerStartRequested event,
    Emitter<ScannerState> emit,
  ) {
    emit(ScannerActive(isTorchOn: _isTorchOn));
  }

  void _onScannerTorchToggled(
    ScannerTorchToggled event,
    Emitter<ScannerState> emit,
  ) {
    _isTorchOn = !_isTorchOn;
    emit(ScannerActive(isTorchOn: _isTorchOn));
  }

  Future<void> _onScannerBarcodeDetected(
    ScannerBarcodeDetected event,
    Emitter<ScannerState> emit,
  ) async {
    emit(ScannerProcessing(event.barcode));
    final result = await getAssetByBarcodeUseCase(event.barcode);
    result.when(
      success: (asset) => emit(ScannerSuccess(asset)),
      failure: (failure) => emit(ScannerFailureState(failure.toString())),
    );
  }

  void _onScannerReset(
    ScannerReset event,
    Emitter<ScannerState> emit,
  ) {
    _isTorchOn = false;
    emit(ScannerInitial());
  }
}
