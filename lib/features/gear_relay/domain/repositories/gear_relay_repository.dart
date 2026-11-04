import '../entities/inspection_angle.dart';

abstract class GearRelayRepository {
  Future<String> submitInspectionBundle({
    required String assetId,
    required List<InspectionAngle> angles,
    double? latitude,
    double? longitude,
  });
}
