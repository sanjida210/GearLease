import '../../domain/entities/hardware_asset.dart';

class HardwareAssetModel extends HardwareAsset {
  const HardwareAssetModel({
    super.id,
    super.vendorId,
    required super.serialNumber,
    super.barcodePayload,
    super.barcodeSymbology = 'CODE_128',
    required super.make,
    required super.model,
    required super.category,
    super.initialValueCents,
    super.msrpCents,
    super.iotDeviceIdentifier,
    super.iotDeviceId,
    super.specificationsMap = const {},
    super.currentConditionRating = 'GRADE_A',
  });

  factory HardwareAssetModel.fromJson(Map<String, dynamic> json) {
    return HardwareAssetModel(
      id: json['id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? json['vendorId'] as String? ?? '',
      serialNumber: json['serial_number'] as String? ?? json['serialNumber'] as String? ?? '',
      barcodePayload: json['barcode_payload'] as String? ?? json['barcodePayload'] as String? ?? '',
      barcodeSymbology: json['barcode_symbology'] as String? ??
          json['barcodeSymbology'] as String? ??
          'CODE_128',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      category: json['category'] as String? ?? '',
      initialValueCents: (json['initial_value_cents'] as num?)?.toInt() ??
          (json['initialValueCents'] as num?)?.toInt() ??
          (json['msrp_cents'] as num?)?.toInt() ??
          0,
      iotDeviceIdentifier: json['iot_device_identifier'] as String? ??
          json['iotDeviceIdentifier'] as String?,
      currentConditionRating: json['current_condition_rating'] as String? ??
          json['currentConditionRating'] as String? ??
          'GRADE_A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'serial_number': serialNumber,
      'barcode_payload': barcodePayload,
      'barcode_symbology': barcodeSymbology,
      'make': make,
      'model': model,
      'category': category,
      'initial_value_cents': initialValueCents,
      'msrp_cents': msrpCents,
      'iot_device_identifier': iotDeviceIdentifier,
      'iot_device_id': iotDeviceId,
      'specifications_map': specificationsMap,
      'current_condition_rating': currentConditionRating,
    };
  }
}
