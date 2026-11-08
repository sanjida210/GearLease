import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/di/injection_container.dart' as di;
import 'package:gearlease/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:gearlease/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.initDependencies(enableHeartbeat: false);
  });

  tearDown(() async {
    await di.resetDependencies();
  });

  testWidgets('GearLeaseApp loads and displays MainShell navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const GearLeaseApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify MainShell is mounted
    expect(find.byType(MainShellScreen), findsOneWidget);

    // Verify initial Fleet Tab Appbar
    expect(find.text('FLEET ASSET OVERVIEW'), findsOneWidget);

    // Verify Navigation Bar items
    expect(find.text('Fleet'), findsOneWidget);
    expect(find.text('Vendor POS'), findsOneWidget);
    expect(find.text('Repayments'), findsOneWidget);

    // Switch to Vendor POS tab
    await tester.tap(find.text('Vendor POS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Underwriting Calculator'), findsOneWidget);
    expect(find.byKey(const Key('vendor_scan_fab')), findsOneWidget);

    // Switch to Repayments / GearRelay tab
    await tester.tap(find.text('Repayments'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('GEARRELAY RETURN GUIDE'), findsOneWidget);
    expect(find.byKey(const Key('capture_angle_button')), findsOneWidget);
  });

  testWidgets('GearLeaseApp renders NavigationRail on tablet viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const GearLeaseApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('GEARLEASE'), findsOneWidget);
  });
}
