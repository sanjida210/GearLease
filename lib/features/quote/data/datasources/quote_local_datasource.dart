import 'dart:convert';
import '../../../../core/storage/database_helper.dart';
import '../models/hardware_asset_model.dart';

abstract class QuoteLocalDataSource {
  Future<void> cacheAsset(HardwareAssetModel asset);
  Future<HardwareAssetModel?> getCachedAssetByBarcode(String barcode);
}

class QuoteLocalDataSourceImpl implements QuoteLocalDataSource {
  final DatabaseHelper databaseHelper;

  QuoteLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> cacheAsset(HardwareAssetModel asset) async {
    await databaseHelper.upsertOfflineAsset({
      'id': asset.id,
      'serial_number': asset.serialNumber,
      'make': asset.make,
      'model': asset.model,
      'msrp_cents': asset.initialValueCents,
      'category': asset.category,
      'payload_json': jsonEncode(asset.toJson()),
    });
  }

  @override
  Future<HardwareAssetModel?> getCachedAssetByBarcode(String barcode) async {
    final row = await databaseHelper.getOfflineAssetByBarcode(barcode);
    if (row != null && row['payload_json'] != null) {
      final json = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      return HardwareAssetModel.fromJson(json);
    }
    return null;
  }
}
