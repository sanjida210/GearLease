import 'package:equatable/equatable.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();

  @override
  List<Object?> get props => [];
}

class ScannerStartRequested extends ScannerEvent {}

class ScannerBarcodeDetected extends ScannerEvent {
  final String barcode;

  const ScannerBarcodeDetected(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

class ScannerTorchToggled extends ScannerEvent {}

class ScannerReset extends ScannerEvent {}
