import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/di/injection_container.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/network_info.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetDependencies();
  });

  tearDown(() async {
    await resetDependencies();
  });

  group('Dependency Injection Setup Tests', () {
    test('initDependencies registers all core singletons', () async {
      await initDependencies();

      expect(sl.isRegistered<ApiClient>(), isTrue);
      expect(sl.isRegistered<DatabaseHelper>(), isTrue);
      expect(sl.isRegistered<SecureStorageService>(), isTrue);
      expect(sl.isRegistered<Connectivity>(), isTrue);
      expect(sl.isRegistered<SharedPreferences>(), isTrue);
      expect(sl.isRegistered<NetworkInfo>(), isTrue);

      expect(sl<ApiClient>(), isA<ApiClient>());
      expect(sl<DatabaseHelper>(), isA<DatabaseHelper>());
      expect(sl<SecureStorageService>(), isA<SecureStorageService>());
      expect(sl<Connectivity>(), isA<Connectivity>());
    });

    test('modular feature dependency registration blocks execute without throwing', () async {
      await initDependencies();

      expect(() => initAuthDependencies(), returnsNormally);
      expect(() => initQuoteDependencies(), returnsNormally);
      expect(() => initScannerDependencies(), returnsNormally);
      expect(() => initTelemetryDependencies(), returnsNormally);
      expect(() => initOfflineSyncDependencies(), returnsNormally);
      expect(() => initGearRelayDependencies(), returnsNormally);
    });

    test('registerMock override allows replacing singletons in test environments', () async {
      await initDependencies();

      final mockApi = MockApiClient();
      registerMock<ApiClient>(mockApi);

      expect(sl<ApiClient>(), equals(mockApi));
    });

    test('resetDependencies cleans up all registrations', () async {
      await initDependencies();
      expect(sl.isRegistered<ApiClient>(), isTrue);

      await resetDependencies();
      expect(sl.isRegistered<ApiClient>(), isFalse);
      expect(sl.isRegistered<DatabaseHelper>(), isFalse);
    });
  });
}
