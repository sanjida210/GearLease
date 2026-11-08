import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/auth/domain/entities/user_session.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gearlease/features/auth/presentation/bloc/auth_state.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_bloc.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_state.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_bloc.dart';
import 'package:gearlease/features/quote/presentation/bloc/quote_state.dart';
import 'package:gearlease/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:gearlease/features/telemetry/domain/entities/machine_telemetry.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_bloc.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_event.dart';
import 'package:gearlease/features/telemetry/presentation/bloc/telemetry_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends Mock implements AuthBloc {}
class MockSyncBloc extends Mock implements SyncBloc {}
class MockQuoteBloc extends Mock implements QuoteBloc {}
class MockTelemetryBloc extends Mock implements TelemetryBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthBloc mockAuthBloc;
  late MockSyncBloc mockSyncBloc;
  late MockQuoteBloc mockQuoteBloc;
  late MockTelemetryBloc mockTelemetryBloc;

  setUpAll(() {
    registerFallbackValue(const StartTelemetryStream('ast-001'));
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockSyncBloc = MockSyncBloc();
    mockQuoteBloc = MockQuoteBloc();
    mockTelemetryBloc = MockTelemetryBloc();

    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockAuthBloc.state).thenReturn(Unauthenticated());

    when(() => mockSyncBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockSyncBloc.state).thenReturn(const SyncIdle(0));

    when(() => mockQuoteBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockQuoteBloc.state).thenReturn(QuoteInitial());

    when(() => mockTelemetryBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockTelemetryBloc.state).thenReturn(
      TelemetryOffline(MachineTelemetry(
        assetId: 'ast-001',
        rpm: 1200,
        temperatureCelsius: 65.0,
        operatingHours: 120.0,
        vibrationG: 0.1,
        status: TelemetryStatus.optimal,
        lastHeartbeat: DateTime.now(),
      )),
    );
  });

  Widget createWidgetUnderTest({
    UserRole? userRole,
    int? initialIndex,
    bool isOffline = false,
  }) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: mockAuthBloc),
          BlocProvider<SyncBloc>.value(value: mockSyncBloc),
          BlocProvider<QuoteBloc>.value(value: mockQuoteBloc),
          BlocProvider<TelemetryBloc>.value(value: mockTelemetryBloc),
        ],
        child: MainShellScreen(
          userRole: userRole,
          initialIndex: initialIndex,
          isOffline: isOffline,
        ),
      ),
    );
  }

  group('Phase 27: Responsive Navigation Shell Specification Tests', () {
    testWidgets('Requirement 1: Mobile Layout renders BottomNavigationBar with 4 tabs', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Fleet'), findsOneWidget);
      expect(find.text('Vendor POS'), findsOneWidget);
      expect(find.text('Repayments'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('SETTINGS & PREFERENCES'), findsOneWidget);
    });

    testWidgets('Requirement 1: Tablet/Desktop Layout renders NavigationRail with expanded labels', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('GEARLEASE'), findsOneWidget);
      expect(find.text('Fleet'), findsOneWidget);
      expect(find.text('Vendor POS'), findsOneWidget);
      expect(find.text('Repayments'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Requirement 2: Global Offline Sync Banner displays amber offline notice when items pending', (tester) async {
      when(() => mockSyncBloc.state).thenReturn(const SyncIdle(3));

      await tester.pumpWidget(createWidgetUnderTest(isOffline: true));
      await tester.pump();

      expect(find.text('Offline Mode — 3 Actions Queued for Sync'), findsOneWidget);
    });

    testWidgets('Requirement 2: Global Offline Sync Banner displays animated sync indicator when flushing queue', (tester) async {
      when(() => mockSyncBloc.state).thenReturn(const SyncRunning(3));

      await tester.pumpWidget(createWidgetUnderTest(isOffline: true));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Syncing queue'), findsOneWidget);
    });

    testWidgets('Requirement 3: Role-based landing — Showroom Agent lands on Vendor POS', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(userRole: UserRole.VENDOR_AGENT));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Underwriting Calculator'), findsOneWidget);
      expect(find.byKey(const Key('vendor_scan_fab')), findsOneWidget);
    });

    testWidgets('Requirement 3: Role-based landing — Lessee lands on Fleet Dashboard', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(userRole: UserRole.LESSEE_OWNER));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('FLEET ASSET OVERVIEW'), findsOneWidget);
    });
  });
}
