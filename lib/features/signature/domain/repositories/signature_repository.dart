import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/mobile_sign_event.dart';

abstract class SignatureRepository {
  Future<Result<MobileSignEvent, Failure>> submitSignature(MobileSignEvent signEvent);
}
