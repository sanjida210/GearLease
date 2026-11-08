import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/hardware_asset.dart';
import '../entities/quote_calculation.dart';

abstract class QuoteRepository {
  Future<Result<HardwareAsset, Failure>> getAssetByBarcode(String barcode);

  Future<Result<QuoteCalculation, Failure>> calculateQuickQuote({
    required String barcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required int requestedTermMonths,
    required RepaymentStructureType repaymentType,
    String? businessEin,
  });
}
