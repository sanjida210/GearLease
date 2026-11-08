import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/storage/database_helper.dart';
import 'package:gearlease/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for desktop/unit test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SecureStorageService Tests', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureStorageService service;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      service = SecureStorageService(storage: mockStorage);
    });

    test('saves and retrieves active tenant ID', () async {
      when(() => mockStorage.write(key: 'active_tenant_id', value: 'tenant-org-7788'))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'active_tenant_id'))
          .thenAnswer((_) async => 'tenant-org-7788');

      await service.saveActiveTenantId('tenant-org-7788');
      final tenantId = await service.getActiveTenantId();

      expect(tenantId, 'tenant-org-7788');
      verify(() => mockStorage.write(key: 'active_tenant_id', value: 'tenant-org-7788')).called(1);
    });

    test('saves and retrieves encryption passkey', () async {
      when(() => mockStorage.write(key: 'encryption_passkey', value: 'aes256-secret-passkey'))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: 'encryption_passkey'))
          .thenAnswer((_) async => 'aes256-secret-passkey');

      await service.saveEncryptionPasskey('aes256-secret-passkey');
      final passkey = await service.getEncryptionPasskey();

      expect(passkey, 'aes256-secret-passkey');
      verify(() => mockStorage.write(key: 'encryption_passkey', value: 'aes256-secret-passkey')).called(1);
    });

    test('clears all auth tokens and tenant data on clearAuth', () async {
      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await service.clearAuth();

      verify(() => mockStorage.delete(key: 'auth_token')).called(1);
      verify(() => mockStorage.delete(key: 'refresh_token')).called(1);
      verify(() => mockStorage.delete(key: 'active_tenant_id')).called(1);
    });
  });

  group('DatabaseHelper SQLite Schema & CRUD Tests', () {
    late DatabaseHelper dbHelper;
    late Database db;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      // Use in-memory SQLite database for test isolation
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (database, version) async {
            await dbHelper.createTables(database);
          },
        ),
      );
      dbHelper.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates sync_queue table and handles item insertions and queries', () async {
      final syncItem = {
        'id': 'sq-001',
        'endpoint': '/api/v1/mobile/quotes/quick-calculate',
        'method': 'POST',
        'payload': '{"amount": 50000}',
        'status': 'PENDING',
        'retry_count': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'idempotency_key': 'uuid-idemp-1122',
      };

      await dbHelper.insertSyncQueueItem(syncItem);
      final pending = await dbHelper.getPendingSyncQueueItems();

      expect(pending.length, 1);
      expect(pending.first['id'], 'sq-001');
      expect(pending.first['status'], 'PENDING');
      expect(pending.first['idempotency_key'], 'uuid-idemp-1122');

      // Update status
      await dbHelper.updateSyncItemStatus('sq-001', 'COMPLETED', retryCount: 1);
      final updated = await dbHelper.getPendingSyncQueueItems();
      expect(updated.isEmpty, isTrue);
    });

    test('creates offline_assets table and handles asset caching', () async {
      final asset = {
        'id': 'ast-roaster-12',
        'serial_number': 'GL-ROAST-2026-9811',
        'make': 'Probat',
        'model': 'P12 III',
        'msrp_cents': 4500000,
        'category': 'Commercial Kitchen',
        'payload_json': '{"warranty_months": 24}',
      };

      await dbHelper.upsertOfflineAsset(asset);

      final fetchedById = await dbHelper.getOfflineAssetById('ast-roaster-12');
      expect(fetchedById, isNotNull);
      expect(fetchedById!['make'], 'Probat');
      expect(fetchedById['msrp_cents'], 4500000);

      final fetchedBySerial = await dbHelper.getOfflineAssetBySerialNumber('GL-ROAST-2026-9811');
      expect(fetchedBySerial, isNotNull);
      expect(fetchedBySerial!['model'], 'P12 III');
    });

    test('creates telemetry_cache table and handles telemetry updates', () async {
      final telemetry = {
        'asset_id': 'ast-roaster-12',
        'rpm': 1450.5,
        'temp_celsius': 78.2,
        'hours': 1248.5,
        'recorded_at': DateTime.now().millisecondsSinceEpoch,
      };

      await dbHelper.upsertTelemetry(telemetry);

      final cached = await dbHelper.getTelemetry('ast-roaster-12');
      expect(cached, isNotNull);
      expect(cached!['rpm'], 1450.5);
      expect(cached['temp_celsius'], 78.2);
      expect(cached['hours'], 1248.5);
    });
  });
}
