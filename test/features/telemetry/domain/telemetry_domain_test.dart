import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';

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
  });
}
