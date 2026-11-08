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
  ];

  setUpAll(() {
    registerFallbackValue(TelemetryFleetSubscribeRequested());
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

  group('FleetDashboardScreen Widget Tests', () {
    testWidgets('renders financial overview metrics and machine cards', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(
        TelemetryStreaming(fleet: testFleet),
      ));
      await tester.pump();

      expect(find.text('FLEET ASSET OVERVIEW'), findsOneWidget);
      expect(find.text('\$118,500'), findsOneWidget);
      expect(find.text('\$2,290.00'), findsOneWidget);
      expect(find.text('Probat P12 Roaster'), findsOneWidget);
      expect(find.text('BrewPro 500 Keg Line'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('OPTIMAL'), findsOneWidget);
    });

    testWidgets('tapping machine card triggers navigation callback', (tester) async {
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
