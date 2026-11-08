import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/utils/result.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/domain/entities/predictive_alert.dart';
import 'package:gearlease/features/telemetry/domain/repositories/telemetry_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockTelemetryRepository extends Mock implements TelemetryRepository {}

void main() {
  group('MachineTelemetry Domain Entity Tests', () {
    final timestamp = DateTime.parse('2026-11-04T12:00:00Z');

    final optimalMachine = MachineTelemetry(
      assetId: 'ast_brewpro500',
      machineName: 'BrewPro 500 Keg Line',
      category: 'Beverage Packaging',
      runningHours: 412.0,
      temperatureCelsius: 64.0,
      motorRpm: 1800.0,
      status: MachineStatus.optimal,
      currentBillingCents: 48000,
      billingType: 'Fixed Lease',
      timestamp: timestamp,
    );

    final warningMachine = MachineTelemetry(
      assetId: 'ast_probat12',
      machineName: 'Probat P12 Roaster',
      category: 'Commercial Kitchen',
      runningHours: 1248.5,
      temperatureCelsius: 78.0,
      motorRpm: 1420.0,
      status: MachineStatus.warning,
      currentBillingCents: 112000,
      billingType: 'Revenue-Indexed',
      timestamp: timestamp,
    );

    test('supports value equality via Equatable', () {
      final duplicate = MachineTelemetry(
        assetId: 'ast_brewpro500',
        machineName: 'BrewPro 500 Keg Line',
        category: 'Beverage Packaging',
        runningHours: 412.0,
        temperatureCelsius: 64.0,
        motorRpm: 1800.0,
        status: MachineStatus.optimal,
        currentBillingCents: 48000,
        billingType: 'Fixed Lease',
        timestamp: timestamp,
      );

      expect(optimalMachine, equals(duplicate));
    });

    test('hasAlert is false for optimal status with temperature < 75C', () {
      expect(optimalMachine.hasAlert, isFalse);
    });

    test('hasAlert is true for warning or fault status or temperature >= 75C', () {
      expect(warningMachine.hasAlert, isTrue);

      final highTempOptimal = MachineTelemetry(
        assetId: 'ast_temp',
        machineName: 'High Temp Unit',
        category: 'Ovens',
        runningHours: 100.0,
        temperatureCelsius: 76.5,
        motorRpm: 1200.0,
        status: MachineStatus.optimal,
        currentBillingCents: 50000,
        billingType: 'Fixed Lease',
        timestamp: timestamp,
      );
      expect(highTempOptimal.hasAlert, isTrue);
    });

    test('Phase 18: supports specific fields: rpm, operatingHours, vibrationG, status (OPTIMAL/WARNING/CRITICAL), lastHeartbeat', () {
      final heartbeatTime = DateTime.parse('2026-11-08T22:30:00Z');

      final telematicsItem = MachineTelemetry(
        assetId: 'ast-cnc-900',
        rpm: 3450.0,
        temperatureCelsius: 68.5,
        operatingHours: 820.0,
        vibrationG: 0.42,
        status: MachineStatus.OPTIMAL,
        lastHeartbeat: heartbeatTime,
      );

      expect(telematicsItem.assetId, 'ast-cnc-900');
      expect(telematicsItem.rpm, 3450.0);
      expect(telematicsItem.motorRpm, 3450.0);
      expect(telematicsItem.temperatureCelsius, 68.5);
      expect(telematicsItem.operatingHours, 820.0);
      expect(telematicsItem.runningHours, 820.0);
      expect(telematicsItem.vibrationG, 0.42);
      expect(telematicsItem.status, MachineStatus.OPTIMAL);
      expect(telematicsItem.status, MachineStatus.optimal);
      expect(telematicsItem.lastHeartbeat, heartbeatTime);
      expect(telematicsItem.timestamp, heartbeatTime);
    });
  });

  group('PredictiveAlert Domain Entity Tests (Phase 18)', () {
    final alertTime = DateTime.parse('2026-11-08T22:35:00Z');

    final testAlert = PredictiveAlert(
      alertId: 'alt-5501',
      assetId: 'ast-cnc-900',
      severity: AlertSeverity.CRITICAL,
      title: 'Spindle Bearing Anomaly Detected',
      description: 'Vibration frequency analysis indicates 87% likelihood of spindle race degradation within 50 operating hours.',
      suggestedAction: 'Schedule precision bearing lubrication or order replacement assembly.',
      timestamp: alertTime,
    );

    test('supports value equality and exposes all required telematics alert fields', () {
      expect(testAlert.alertId, 'alt-5501');
      expect(testAlert.assetId, 'ast-cnc-900');
      expect(testAlert.severity, AlertSeverity.CRITICAL);
      expect(testAlert.title, 'Spindle Bearing Anomaly Detected');
      expect(testAlert.description, contains('87% likelihood'));
      expect(testAlert.suggestedAction, contains('lubrication'));
      expect(testAlert.timestamp, alertTime);

      final duplicate = PredictiveAlert(
        alertId: 'alt-5501',
        assetId: 'ast-cnc-900',
        severity: AlertSeverity.CRITICAL,
        title: 'Spindle Bearing Anomaly Detected',
        description: 'Vibration frequency analysis indicates 87% likelihood of spindle race degradation within 50 operating hours.',
        suggestedAction: 'Schedule precision bearing lubrication or order replacement assembly.',
        timestamp: alertTime,
      );

      expect(testAlert, equals(duplicate));
    });
  });

  group('TelemetryRepository Contract Tests (Phase 18)', () {
    late MockTelemetryRepository mockRepository;

    setUp(() {
      mockRepository = MockTelemetryRepository();
    });

    test('watchMachineTelemetry returns Stream<MachineTelemetry>', () {
      final sample = MachineTelemetry(
        assetId: 'ast-01',
        rpm: 1200,
        temperatureCelsius: 60,
        operatingHours: 100,
        vibrationG: 0.1,
        status: MachineStatus.OPTIMAL,
        lastHeartbeat: DateTime.now(),
      );

      when(() => mockRepository.watchMachineTelemetry('ast-01'))
          .thenAnswer((_) => Stream.value(sample));

      expect(mockRepository.watchMachineTelemetry('ast-01'), emits(sample));
    });

    test('getActiveAlerts returns Future<Result<List<PredictiveAlert>, Failure>>', () async {
      final alert = PredictiveAlert(
        alertId: 'alt-01',
        assetId: 'ast-01',
        severity: AlertSeverity.HIGH,
        title: 'High Thermal Drift',
        description: 'Sensor #2 thermal spike',
        suggestedAction: 'Inspect coolant lines',
        timestamp: DateTime.now(),
      );

      when(() => mockRepository.getActiveAlerts('ast-01'))
          .thenAnswer((_) async => Result.success([alert]));

      final result = await mockRepository.getActiveAlerts('ast-01');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.first.title, 'High Thermal Drift');
    });

    test('requestMaintenanceService returns Future<Result<void, Failure>>', () async {
      when(() => mockRepository.requestMaintenanceService('ast-01', 'alt-01'))
          .thenAnswer((_) async => Result.success(null));

      final result = await mockRepository.requestMaintenanceService('ast-01', 'alt-01');
      expect(result.isSuccess, isTrue);
    });
  });
}
