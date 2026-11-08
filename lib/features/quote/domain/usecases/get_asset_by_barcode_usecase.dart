import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/hardware_asset.dart';
import '../repositories/quote_repository.dart';

class GetAssetByBarcodeUseCase {
  final QuoteRepository repository;

  GetAssetByBarcodeUseCase(this.repository);

  Future<Result<HardwareAsset, Failure>> call(String barcode) {
    return repository.getAssetByBarcode(barcode);
  }
}
