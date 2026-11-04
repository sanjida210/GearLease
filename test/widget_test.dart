import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/di/injection_container.dart' as di;
import 'package:gearlease/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.initDependencies();
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('GearLeaseApp loads and displays MainShell navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const GearLeaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Active Fleet Supervision'), findsNWidgets(2));
    expect(find.text('Fleet'), findsOneWidget);
    expect(find.text('Vendor POS'), findsOneWidget);
    expect(find.text('Repayments'), findsOneWidget);
  });
}
