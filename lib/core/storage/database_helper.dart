import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String tableSyncQueue = 'sync_queue';
  static const String tableOfflineAssets = 'offline_assets';
  static const String tableTelemetryCache = 'telemetry_cache';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.syncDatabaseName);
    return _database!;
  }

  @visibleForTesting
  void setDatabaseForTesting(Database testDb) {
    _database = testDb;
  }

  Future<Database> _initDB(String filePath) async {
    // FFI fallback for Windows / Linux / Desktop test environments
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.syncDatabaseVersion,
      onCreate: (db, version) => createTables(db),
    );
  }

  Future<void> createTables(Database db) async {
    // 1. Sync Queue Table
    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id TEXT PRIMARY KEY,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        idempotency_key TEXT NOT NULL
      )
    ''');

    // 2. Offline Assets Table
    await db.execute('''
      CREATE TABLE $tableOfflineAssets (
        id TEXT PRIMARY KEY,
        serial_number TEXT NOT NULL,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        msrp_cents INTEGER NOT NULL,
        category TEXT NOT NULL,
        payload_json TEXT NOT NULL
      )
    ''');

    // 3. Telemetry Cache Table
    await db.execute('''
      CREATE TABLE $tableTelemetryCache (
        asset_id TEXT PRIMARY KEY,
        rpm REAL NOT NULL,
        temp_celsius REAL NOT NULL,
        hours REAL NOT NULL,
        recorded_at INTEGER NOT NULL
      )
    ''');

    // Indices for performance
    await db.execute('CREATE INDEX idx_sync_queue_status ON $tableSyncQueue(status)');
    await db.execute('CREATE INDEX idx_offline_assets_serial ON $tableOfflineAssets(serial_number)');
  }

  // --- Sync Queue Operations ---
  Future<int> insertSyncQueueItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert(
      tableSyncQueue,
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSyncQueueItems() async {
    final db = await database;
    return await db.query(
      tableSyncQueue,
      where: 'status IN (?, ?)',
      whereArgs: ['PENDING', 'QUEUED'],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getSyncQueueItemById(String id) async {
    final db = await database;
    final results = await db.query(
      tableSyncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSyncQueueItems() async {
    final db = await database;
    return await db.query(
      tableSyncQueue,
      orderBy: 'created_at ASC',
    );
  }

  Future<int> updateSyncItemStatus(
    String id,
    String status, {
    int? retryCount,
    String? errorMessage,
  }) async {
    final db = await database;
    final values = <String, dynamic>{'status': status};
    if (retryCount != null) {
      values['retry_count'] = retryCount;
    }
    return await db.update(
      tableSyncQueue,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSyncQueueItem(String id) async {
    final db = await database;
    return await db.delete(
      tableSyncQueue,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCompletedSyncItems() async {
    final db = await database;
    return await db.delete(
      tableSyncQueue,
      where: 'status IN (?, ?)',
      whereArgs: ['SYNCED', 'COMPLETED'],
    );
  }

  // --- Offline Assets Operations ---
  Future<int> upsertOfflineAsset(Map<String, dynamic> asset) async {
    final db = await database;
    return await db.insert(
      tableOfflineAssets,
      asset,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getOfflineAssetById(String id) async {
    final db = await database;
    final results = await db.query(
      tableOfflineAssets,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getOfflineAssetBySerialNumber(String serialNumber) async {
    final db = await database;
    final results = await db.query(
      tableOfflineAssets,
      where: 'serial_number = ?',
      whereArgs: [serialNumber],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getOfflineAssetByBarcode(String barcode) async {
    final db = await database;
    final results = await db.query(
      tableOfflineAssets,
      where: 'serial_number = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;

    final all = await db.query(tableOfflineAssets);
    for (final row in all) {
      final payload = row['payload_json'] as String?;
      if (payload != null && payload.contains(barcode)) {
        return row;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllOfflineAssets() async {
    final db = await database;
    return await db.query(tableOfflineAssets);
  }

  // --- Telemetry Cache Operations ---
  Future<int> upsertTelemetry(Map<String, dynamic> telemetry) async {
    final db = await database;
    return await db.insert(
      tableTelemetryCache,
      telemetry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTelemetry(String assetId) async {
    final db = await database;
    final results = await db.query(
      tableTelemetryCache,
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
