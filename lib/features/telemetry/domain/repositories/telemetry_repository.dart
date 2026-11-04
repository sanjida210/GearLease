import '../entities/machine_telemetry.dart';

abstract class TelemetryRepository {
  Stream<List<MachineTelemetry>> watchFleetTelemetry();
  Stream<MachineTelemetry> watchMachineTelemetry(String assetId);
  Future<bool> scheduleWarrantyService(String assetId, String notes);
}
