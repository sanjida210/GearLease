import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_colors.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/fleet/presentation/screens/fleet_dashboard_screen.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_bloc.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_event.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_state.dart';
import 'package:mocktail/mocktail.dart';

class MockTelemetryBloc extends Mock implements TelemetryBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTelemetryBloc mockTelemetryBloc;

  // Test machines with Optimal (Green), Warning (Amber), and Fault/Critical (Red)
  final optimalMachine = MachineTelemetry(
    assetId: 'ast_optimal_01',
    machineName: 'BrewPro 500 Keg Line',
    category: 'Beverage Packaging',
    runningHours: 412.0,
    temperatureCelsius: 64.0, // < 75.0 -> Green
    motorRpm: 1800.0,
    status: MachineStatus.optimal, // Optimal -> Green
    currentBillingCents: 48000,
    billingType: 'Fixed Lease',
    timestamp: DateTime.parse('2026-11-09T00:00:00Z'),
  );

  final warningMachine = MachineTelemetry(
    assetId: 'ast_warning_02',
    machineName: 'Probat P12 Roaster',
    category: 'Commercial Kitchen',
    runningHours: 1248.5,
    temperatureCelsius: 78.0, // >= 75.0 && < 85.0 -> Amber
    motorRpm: 1420.0,
    status: MachineStatus.warning, // Warning -> Amber
    currentBillingCents: 112000,
    billingType: 'Revenue-Indexed',
    timestamp: DateTime.parse('2026-11-09T00:00:00Z'),
  );

  final criticalMachine = MachineTelemetry(
    assetId: 'ast_critical_03',
    machineName: 'Haas VF-2 CNC Mill',
    category: 'Precision Manufacturing',
    runningHours: 2150.0,
    temperatureCelsius: 88.5, // >= 85.0 -> Red
    motorRpm: 7500.0,
    status: MachineStatus.fault, // Fault -> Red (Critical)
    currentBillingCents: 195000,
    billingType: 'Pay-Per-Use',
    timestamp: DateTime.parse('2026-11-09T00:00:00Z'),
  );

  final testFleet = [optimalMachine, warningMachine, criticalMachine];

  setUpAll(() {
    registerFallbackValue(TelemetryFleetSubscribeRequested());
    registerFallbackValue(const StopTelemetryStream());
  });

  setUp(() {
    mockTelemetryBloc = MockTelemetryBloc();
    when(() => mockTelemetryBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockTelemetryBloc.state).thenReturn(TelemetryStreaming(fleet: testFleet));
  });

  Widget buildFleetDashboard({
    TelemetryState? state,
    void Function(String)? onNavigate,
  }) {
    if (state != null) {
      when(() => mockTelemetryBloc.state).thenReturn(state);
    }

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: BlocProvider<TelemetryBloc>.value(
        value: mockTelemetryBloc,
        child: FleetDashboardScreen(
          onNavigateToDiagnostics: onNavigate,
        ),
      ),
    );
  }

  group('Phase 29 — FleetDashboardScreen Telemetry Status Pills & Visual Validations', () {
    testWidgets('1. Verifies machine telemetry status pills render green/amber/red based on data values', (tester) async {
      await tester.pumpWidget(buildFleetDashboard());
      await tester.pumpAndSettle();

      // Find all Text widgets for temperature pills
      // Optimal: 64.0°C should be green
      final optimalTempFinder = find.text('64.0°C');
      expect(optimalTempFinder, findsOneWidget);
      final optimalText = tester.widget<Text>(optimalTempFinder);
      expect(optimalText.style?.color, equals(AppColors.performanceGreen));

      // Warning: 78.0°C should be amber
      final warningTempFinder = find.text('78.0°C');
      expect(warningTempFinder, findsOneWidget);
      final warningText = tester.widget<Text>(warningTempFinder);
      expect(warningText.style?.color, equals(AppColors.industrialAmber));

      // Critical: 88.5°C should be red
      final criticalTempFinder = find.text('88.5°C');
      expect(criticalTempFinder, findsOneWidget);
      final criticalText = tester.widget<Text>(criticalTempFinder);
      expect(criticalText.style?.color, equals(AppColors.criticalRed));

      // Find and verify status badges (the card badge is the last Text widget with the status label)
      // Optimal status badge (Green)
      final optimalBadge = tester.widgetList<Text>(find.text('Optimal')).last;
      expect(optimalBadge.style?.color, equals(AppColors.performanceGreen));

      // Warning status badge (Amber)
      final warningBadge = tester.widgetList<Text>(find.text('Warning')).last;
      expect(warningBadge.style?.color, equals(AppColors.industrialAmber));

      // Critical status badge (Red)
      final criticalBadge = tester.widgetList<Text>(find.text('Critical')).last;
      expect(criticalBadge.style?.color, equals(AppColors.criticalRed));
    });

    testWidgets('2. Verifies status filter chips and live indicator dots render expected theme colors', (tester) async {
      await tester.pumpWidget(buildFleetDashboard());
      await tester.pumpAndSettle();

      // Filter chips present
      expect(find.byKey(const Key('filter_chip_all')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_optimal')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_warning')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_critical')), findsOneWidget);

      // Tap 'Optimal' filter chip -> only BrewPro 500 Keg Line is visible
      await tester.tap(find.byKey(const Key('filter_chip_optimal')));
      await tester.pumpAndSettle();

      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsNothing);
      expect(find.text('Haas VF-2 CNC Mill'), findsNothing);

      // Tap 'Critical' filter chip -> only Haas VF-2 CNC Mill is visible
      await tester.tap(find.byKey(const Key('filter_chip_critical')));
      await tester.pumpAndSettle();

      expect(find.text('Haas VF-2 CNC Mill'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsNothing);
      expect(find.text('Probat P12 Roaster'), findsNothing);
    });

    testWidgets('3. Verifies machine card tap navigates with correct assetId', (tester) async {
      String? navigatedId;

      await tester.pumpWidget(buildFleetDashboard(
        onNavigate: (id) => navigatedId = id,
      ));
      await tester.pumpAndSettle();

      final machineFinder = find.text('Haas VF-2 CNC Mill');
      await tester.ensureVisible(machineFinder);
      await tester.tap(machineFinder);
      await tester.pump();

      expect(navigatedId, equals('ast_critical_03'));
    });
  });
}
