import 'package:equatable/equatable.dart';

class HardwareAsset extends Equatable {
  final String id;
  final String vendorId;
  final String serialNumber;
  final String barcodePayload;
  final String barcodeSymbology;
  final String make;
  final String model;
  final String category;
  final int initialValueCents;
  final String? iotDeviceIdentifier;
  final String currentConditionRating;

  const HardwareAsset({
    required this.id,
    required this.vendorId,
    required this.serialNumber,
    required this.barcodePayload,
    this.barcodeSymbology = 'CODE_128',
    required this.make,
    required this.model,
    required this.category,
    required this.initialValueCents,
    this.iotDeviceIdentifier,
    this.currentConditionRating = 'GRADE_A',
  });

  String get displayName => '$make $model';

  @override
  List<Object?> get props => [
        id,
        vendorId,
        serialNumber,
        barcodePayload,
        barcodeSymbology,
        make,
        model,
        category,
        initialValueCents,
        iotDeviceIdentifier,
        currentConditionRating,
      ];
}
