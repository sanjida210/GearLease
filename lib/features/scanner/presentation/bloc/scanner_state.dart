import 'package:equatable/equatable.dart';
import 'package:gearlease/features/quote/domain/entities/hardware_asset.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {}

class ScannerActive extends ScannerState {
  final bool isTorchOn;

  const ScannerActive({this.isTorchOn = false});

  @override
  List<Object?> get props => [isTorchOn];
}

class ScannerProcessing extends ScannerState {
  final String barcode;

  const ScannerProcessing(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class ScannerSuccess extends ScannerState {
  final HardwareAsset asset;

  const ScannerSuccess(this.asset);

  @override
  List<Object?> get props => [asset];
}

class ScannerFailureState extends ScannerState {
  final String message;

  const ScannerFailureState(this.message);

  @override
  List<Object?> get props => [message];
}
