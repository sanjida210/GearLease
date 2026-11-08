import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/theme/app_theme.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_bloc.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_event.dart';
import 'package:gearlease/features/offline_sync/presentation/bloc/sync_state.dart';
import 'package:gearlease/features/offline_sync/presentation/widgets/offline_sync_banner.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncBloc extends Mock implements SyncBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSyncBloc mockSyncBloc;

  setUpAll(() {
    registerFallbackValue(SyncTriggered());
  });

  setUp(() {
    mockSyncBloc = MockSyncBloc();
    when(() => mockSyncBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(SyncState state) {
    when(() => mockSyncBloc.state).thenReturn(state);

    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BlocProvider<SyncBloc>.value(
          value: mockSyncBloc,
          child: const OfflineSyncBanner(),
        ),
      ),
    );
  }

  group('OfflineSyncBanner Widget Tests', () {
    testWidgets('hides completely when pendingCount is 0', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SyncIdle(0)));
      await tester.pump();

      expect(find.byKey(const Key('offline_sync_now_button')), findsNothing);
      expect(find.textContaining('OFFLINE QUEUE:'), findsNothing);
    });

    testWidgets('renders banner and dispatches SyncTriggered on button tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SyncIdle(3)));
      await tester.pump();

      expect(find.text('OFFLINE QUEUE: 3 PENDING RECORDS'), findsOneWidget);
      expect(find.byKey(const Key('offline_sync_now_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('offline_sync_now_button')));
      await tester.pump();

      verify(() => mockSyncBloc.add(any(that: isA<SyncTriggered>()))).called(1);
    });

    testWidgets('renders CircularProgressIndicator when state is SyncRunning', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const SyncRunning(3)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
