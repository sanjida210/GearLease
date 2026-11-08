import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

  final testFleet = [
    MachineTelemetry(
      assetId: 'ast_probat12',
      machineName: 'Probat P12 Roaster',
      category: 'Commercial Kitchen',
      runningHours: 1248.5,
      temperatureCelsius: 78.0,
      motorRpm: 1420.0,
      status: MachineStatus.warning,
      currentBillingCents: 112000,
      billingType: 'Revenue-Indexed',
      timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
    ),
    MachineTelemetry(
      assetId: 'ast_brewpro500',
      machineName: 'BrewPro 500 Keg Line',
      category: 'Beverage Packaging',
      runningHours: 412.0,
      temperatureCelsius: 64.0,
      motorRpm: 1800.0,
      status: MachineStatus.optimal,
      currentBillingCents: 48000,
      billingType: 'Fixed Lease',
      timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
    ),
    MachineTelemetry(
      assetId: 'ast_haas_cnc',
      machineName: 'Haas VF-2 CNC Mill',
      category: 'Precision Manufacturing',
      runningHours: 2150.0,
      temperatureCelsius: 88.5,
      motorRpm: 7500.0,
      status: MachineStatus.fault,
      currentBillingCents: 195000,
      billingType: 'Pay-Per-Use',
      timestamp: DateTime.parse('2026-11-04T10:30:00Z'),
    ),
  ];

  setUpAll(() {
    registerFallbackValue(TelemetryFleetSubscribeRequested());
    registerFallbackValue(const StopTelemetryStream());
  });

  setUp(() {
    mockTelemetryBloc = MockTelemetryBloc();
    when(() => mockTelemetryBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(TelemetryState state, {void Function(String)? onNavigate}) {
    when(() => mockTelemetryBloc.state).thenReturn(state);

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

  group('Phase 21 — Lessee Fleet Dashboard Screen Tests', () {
    testWidgets('renders Fleet Metrics Bar with total assets, active hours, and monthly forecast', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
      ));
      await tester.pump();

      // App Header
      expect(find.text('FLEET ASSET OVERVIEW'), findsOneWidget);

      // Requirement 1: Fleet Metrics Bar
      expect(find.text('TOTAL LEASED ASSETS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      expect(find.text('ACTIVE OPERATING HOURS'), findsOneWidget);
      // 1248.5 + 412.0 + 2150.0 = 3810.5 hrs
      expect(find.text('3,810.5 hrs'), findsOneWidget);

      expect(find.text('MONTHLY PAYMENT FORECAST'), findsOneWidget);
      // 1120 + 480 + 1950 = $3,550.00
      expect(find.text('\$3,550.00'), findsOneWidget);
    });

    testWidgets('renders Machine Asset Cards with make/model, serial, status badges, telemetry pills, and ACH details', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
      ));
      await tester.pump();

      // Make & Model
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('Haas VF-2 CNC Mill'), findsOneWidget);

      // Machine Serial Numbers
      expect(find.textContaining('SN: ast_probat12'), findsOneWidget);
      expect(find.textContaining('SN: ast_brewpro500'), findsOneWidget);
      expect(find.textContaining('SN: ast_haas_cnc'), findsOneWidget);

      // Status Badges (Optimal, Warning, Critical) - present on both filter chip and card badge
      expect(find.text('Optimal'), findsNWidgets(2));
      expect(find.text('Warning'), findsNWidgets(2));
      expect(find.text('Critical'), findsNWidgets(2));

      // Real-Time Telemetry Pills: Hours, RPM, Temperature
      expect(find.text('1,248.5 hrs'), findsOneWidget);
      expect(find.text('1,420 RPM'), findsOneWidget);
      expect(find.text('78.0°C'), findsOneWidget);

      expect(find.text('412.0 hrs'), findsOneWidget);
      expect(find.text('1,800 RPM'), findsOneWidget);
      expect(find.text('64.0°C'), findsOneWidget);

      // Next ACH Auto-Debit details
      expect(find.textContaining('Next ACH Auto-Debit: Nov 15'), findsNWidgets(3));
      expect(find.text('\$1,120.00 / mo'), findsOneWidget);
      expect(find.text('\$480.00 / mo'), findsOneWidget);
      expect(find.text('\$1,950.00 / mo'), findsOneWidget);
    });

    testWidgets('filters machines dynamically when typing serial in search bar', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
      ));
      await tester.pump();

      expect(find.byKey(const Key('fleet_search_input')), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);

      // Enter serial search query
      await tester.enterText(find.byKey(const Key('fleet_search_input')), 'brewpro');
      await tester.pump();

      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsNothing);
      expect(find.text('Haas VF-2 CNC Mill'), findsNothing);

      // Clear search
      await tester.enterText(find.byKey(const Key('fleet_search_input')), '');
      await tester.pump();

      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('Haas VF-2 CNC Mill'), findsOneWidget);
    });

    testWidgets('filters machines by operational status filter chips (All, Optimal, Warning, Critical)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
      ));
      await tester.pump();

      // Filter by 'Warning'
      await tester.tap(find.byKey(const Key('filter_chip_warning')));
      await tester.pump();

      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsNothing);
      expect(find.text('Haas VF-2 CNC Mill'), findsNothing);

      // Filter by 'Critical'
      await tester.tap(find.byKey(const Key('filter_chip_critical')));
      await tester.pump();

      expect(find.text('Haas VF-2 CNC Mill'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsNothing);
      expect(find.text('BrewPro 500 Keg Line'), findsNothing);

      // Reset to 'All'
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pump();

      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('Haas VF-2 CNC Mill'), findsOneWidget);
    });

    testWidgets('tapping machine card triggers navigation callback with assetId', (tester) async {
      String? tappedAsset;

      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
        onNavigate: (assetId) => tappedAsset = assetId,
      ));
      await tester.pump();

      await tester.tap(find.text('Probat P12 Roaster'));
      await tester.pump();

      expect(tappedAsset, equals('ast_probat12'));
    });
  });
}
