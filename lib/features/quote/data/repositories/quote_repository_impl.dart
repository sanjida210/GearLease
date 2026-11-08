import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/hardware_asset.dart';
import '../../domain/entities/quote_calculation.dart';
import '../../domain/repositories/quote_repository.dart';
import '../../domain/usecases/calculate_quick_quote_usecase.dart';
import '../datasources/quote_local_datasource.dart';
import '../datasources/quote_remote_datasource.dart';

class QuoteRepositoryImpl implements QuoteRepository {
  final QuoteRemoteDataSource remoteDataSource;
  final QuoteLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  QuoteRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<HardwareAsset, Failure>> getAssetByBarcode(String barcode) async {
    final isOnline = await networkInfo.isConnected;

    if (isOnline) {
      try {
        final remoteAsset = await remoteDataSource.lookupAssetByBarcode(barcode);
        await localDataSource.cacheAsset(remoteAsset);
        return Result.success(remoteAsset);
      } on ServerException catch (e) {
        // Fallback to local cache if available
        final cached = await localDataSource.getCachedAssetByBarcode(barcode);
        if (cached != null) {
          return Result.success(cached);
        }
        return Result.failure(ServerFailure(e.message, statusCode: e.statusCode));
      } catch (e) {
        final cached = await localDataSource.getCachedAssetByBarcode(barcode);
        if (cached != null) {
          return Result.success(cached);
        }
        return Result.failure(ServerFailure(e.toString()));
      }
    } else {
      final cached = await localDataSource.getCachedAssetByBarcode(barcode);
      if (cached != null) {
        return Result.success(cached);
      }
      return Result.failure(
        const NetworkFailure('Device is offline and asset is not cached locally.'),
      );
    }
  }

  @override
  Future<Result<QuoteCalculation, Failure>> calculateQuickQuote({
    required String barcode,
    required String vendorOrgId,
    required int invoiceAmountCents,
    required int requestedTermMonths,
    required RepaymentStructureType repaymentType,
    String? businessEin,
  }) async {
    final isOnline = await networkInfo.isConnected;

    if (isOnline) {
      try {
        final quote = await remoteDataSource.calculateQuickQuote(
          barcode: barcode,
          vendorOrgId: vendorOrgId,
          invoiceAmountCents: invoiceAmountCents,
          requestedTermMonths: requestedTermMonths,
          repaymentType: repaymentType,
          businessEin: businessEin,
        );
        return Result.success(quote);
      } catch (_) {
        // High-availability showroom floor fallback: calculate offline
        final fallback = CalculateQuickQuoteUseCase.calculateClientSideFallback(
          invoiceAmountCents: invoiceAmountCents,
          termMonths: requestedTermMonths,
          repaymentType: repaymentType,
        );
        return Result.success(fallback);
      }
    } else {
      // Offline instant underwriting calculator fallback
      final fallback = CalculateQuickQuoteUseCase.calculateClientSideFallback(
        invoiceAmountCents: invoiceAmountCents,
        termMonths: requestedTermMonths,
        repaymentType: repaymentType,
      );
      return Result.success(fallback);
    }
  }
}
