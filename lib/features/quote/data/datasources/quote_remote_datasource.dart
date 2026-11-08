import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/quote_calculation.dart';
import '../models/hardware_asset_model.dart';
import '../models/quote_calculation_model.dart';

abstract class QuoteRemoteDataSource {
  Future<HardwareAssetModel> lookupAssetByBarcode(String barcode);

  Future<QuoteCalculationModel> calculateQuickQuote({
    required String barcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required int requestedTermMonths,
    required RepaymentStructureType repaymentType,
    String? businessEin,
  });
}

class QuoteRemoteDataSourceImpl implements QuoteRemoteDataSource {
  final ApiClient apiClient;

  QuoteRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<HardwareAssetModel> lookupAssetByBarcode(String barcode) async {
    try {
      final response = await apiClient.dio.get(
        '/api/v1/mobile/assets/barcode/$barcode',
      );

      if (response.statusCode == 200 && response.data != null) {
        return HardwareAssetModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } else {
        throw ServerException(
          'Asset lookup failed with status code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Asset lookup network failure',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<QuoteCalculationModel> calculateQuickQuote({
    required String barcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required int requestedTermMonths,
    required RepaymentStructureType repaymentType,
    String? businessEin,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/api/v1/mobile/quotes/quick-calculate',
        data: {
          'scanned_asset_barcode': barcode,
          'vendor_org_id': vendorOrgId,
          'invoice_amount_cents': invoiceAmountCents,
          'requested_term_months': requestedTermMonths,
          'pricing_model_requested': repaymentType.name,
          if (businessEin != null) 'business_ein': businessEin,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return QuoteCalculationModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      } else {
        throw ServerException(
          'Quote calculation failed with status code ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Quote calculation network failure',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
