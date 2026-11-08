import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../storage/database_helper.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/datasources/biometric_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

final sl = GetIt.instance;

/// Initializes all application-wide singletons, database helpers, and feature dependencies.
Future<void> initDependencies() async {
  // 1. External & Platform Services
  final sharedPreferences = await SharedPreferences.getInstance();
  if (!sl.isRegistered<SharedPreferences>()) {
    sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  }
  if (!sl.isRegistered<Connectivity>()) {
    sl.registerLazySingleton<Connectivity>(() => Connectivity());
  }
  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      ),
    );
  }

  // 2. Core Storage & Network Singletons
  if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerLazySingleton<SecureStorageService>(
      () => SecureStorageService(storage: sl<FlutterSecureStorage>()),
    );
  }
  if (!sl.isRegistered<DatabaseHelper>()) {
    sl.registerLazySingleton<DatabaseHelper>(
      () => DatabaseHelper.instance,
    );
  }
  if (!sl.isRegistered<NetworkInfo>()) {
    sl.registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(sl<Connectivity>()),
    );
  }
  if (!sl.isRegistered<ApiClient>()) {
    sl.registerLazySingleton<ApiClient>(
      () => ApiClient(secureStorageService: sl<SecureStorageService>()),
    );
  }

  // 3. Modular Feature Blocks
  initAuthDependencies();
  initQuoteDependencies();
  initScannerDependencies();
  initTelemetryDependencies();
  initOfflineSyncDependencies();
  initGearRelayDependencies();
}

/// Feature DI: Authentication & Biometrics
void initAuthDependencies() {
  if (!sl.isRegistered<AuthRemoteDataSource>()) {
    sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
    );
  }
  if (!sl.isRegistered<BiometricLocalDataSource>()) {
    sl.registerLazySingleton<BiometricLocalDataSource>(
      () => BiometricLocalDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl<AuthRemoteDataSource>(),
        biometricDataSource: sl<BiometricLocalDataSource>(),
        storageService: sl<SecureStorageService>(),
      ),
    );
  }
}

/// Feature DI: Underwriting & Quick Quote Calculator
void initQuoteDependencies() {
  // Quote calculations & term sliders
}

/// Feature DI: Native Optical & Barcode Scanner
void initScannerDependencies() {
  // Camera & MLKit barcode lookup services
}

/// Feature DI: Real-Time IoT Machine Telemetry
void initTelemetryDependencies() {
  // WebSocket streams & predictive diagnostics
}

/// Feature DI: Offline-First Queue & Sync Engine
void initOfflineSyncDependencies() {
  // Sync queue worker & conflict resolution
}

/// Feature DI: GearRelay 4-Angle Return Inspection
void initGearRelayDependencies() {
  // Camera return tools & image compression
}

/// Test Hook: Resets GetIt instance for clean test execution
Future<void> resetDependencies() async {
  await sl.reset();
}

/// Test Hook: Registers or overrides a mock instance for testing
void registerMock<T extends Object>(T mockInstance) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(mockInstance);
}
