import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/return_inspection.dart';

abstract class GearRelayRepository {
  Future<Result<ReturnInspection, Failure>> submitInspectionBundle(
    String leaseId,
    Map<String, String> photoPaths,
  );
}
