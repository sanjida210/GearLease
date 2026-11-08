import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/hardware_asset.dart';
import '../entities/quote_calculation.dart';

abstract class QuoteRepository {
  /// Look up an asset by its barcode payload (Phase 11 contract).
  Future<Result<HardwareAsset, Failure>> lookupAssetByBarcode(String barcode);

  /// Calculate dynamic underwriting quote for equipment leasing (Phase 11 contract).
  Future<Result<QuoteCalculation, Failure>> calculateDynamicQuote(
    String assetId,
    int termMonths,
    PricingType pricingType,
    int businessEin,
  );

  /// Alias for barcode asset lookup.
  Future<Result<HardwareAsset, Failure>> getAssetByBarcode(String barcode);

  /// Detailed multi-parameter quote calculation.
  Future<Result<QuoteCalculation, Failure>> calculateQuickQuote({
    required String barcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required int requestedTermMonths,
    required RepaymentStructureType repaymentType,
    String? businessEin,
  });
}
