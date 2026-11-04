import '../entities/quote_calculation.dart';

abstract class QuoteRepository {
  Future<QuoteCalculation> calculateQuickQuote({
    required String assetBarcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required String businessEin,
    required int requestedTermMonths,
    required RepaymentStructureType pricingModelRequested,
  });
}
