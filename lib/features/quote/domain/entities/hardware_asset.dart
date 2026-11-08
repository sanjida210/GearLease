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
  final int msrpCents;
  final String? iotDeviceId;
  final Map<String, dynamic> specificationsMap;
  final String currentConditionRating;

  const HardwareAsset({
    this.id = '',
    this.vendorId = '',
    required this.serialNumber,
    this.barcodePayload = '',
    this.barcodeSymbology = 'CODE_128',
    required this.make,
    required this.model,
    required this.category,
    int? msrpCents,
    int? initialValueCents,
    String? iotDeviceId,
    String? iotDeviceIdentifier,
    this.specificationsMap = const {},
    this.currentConditionRating = 'GRADE_A',
  })  : msrpCents = msrpCents ?? initialValueCents ?? 0,
        iotDeviceId = iotDeviceId ?? iotDeviceIdentifier;

  int get initialValueCents => msrpCents;
  String? get iotDeviceIdentifier => iotDeviceId;
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
        msrpCents,
        iotDeviceId,
        specificationsMap,
        currentConditionRating,
      ];
}
