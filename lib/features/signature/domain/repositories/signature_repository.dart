import '../entities/mobile_sign_event.dart';

abstract class SignatureRepository {
  Future<MobileSignEvent> submitSignature({
    required String contractId,
    required String signatureVectorPath,
    String? biometricUsed,
    double? gpsLatitude,
    double? gpsLongitude,
  });
}
