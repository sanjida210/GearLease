import '../../../../features/quote/domain/entities/hardware_asset.dart';

abstract class ScannerRepository {
  Future<HardwareAsset?> lookupAssetByBarcode(String barcodePayload);
}
