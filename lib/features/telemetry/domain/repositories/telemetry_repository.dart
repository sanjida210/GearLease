import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/machine_telemetry.dart';
import '../entities/predictive_alert.dart';

abstract class TelemetryRepository {
  Stream<List<MachineTelemetry>> watchFleetTelemetry();
  Stream<MachineTelemetry> watchMachineTelemetry(String assetId);
  Future<Result<List<PredictiveAlert>, Failure>> getActiveAlerts(String assetId);
  Future<Result<void, Failure>> requestMaintenanceService(String assetId, String alertId);
  Future<bool> scheduleWarrantyService(String assetId, String notes);
}
