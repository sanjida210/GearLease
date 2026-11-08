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
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/quote/data/datasources/quote_local_datasource.dart';
import '../../features/quote/data/datasources/quote_remote_datasource.dart';
import '../../features/quote/data/repositories/quote_repository_impl.dart';
import '../../features/quote/domain/repositories/quote_repository.dart';
import '../../features/quote/domain/usecases/calculate_quick_quote_usecase.dart';
import '../../features/quote/domain/usecases/get_asset_by_barcode_usecase.dart';
import '../../features/quote/presentation/bloc/quote_bloc.dart';
import '../../features/scanner/presentation/bloc/scanner_bloc.dart';
import '../../features/signature/data/repositories/signature_repository_impl.dart';
import '../../features/signature/domain/repositories/signature_repository.dart';
import '../../features/signature/presentation/bloc/signature_bloc.dart';
import '../../features/telemetry/data/datasources/telemetry_ws_datasource.dart';
import '../../features/telemetry/data/repositories/telemetry_repository_impl.dart';
import '../../features/telemetry/domain/repositories/telemetry_repository.dart';
import '../../features/telemetry/presentation/bloc/telemetry_bloc.dart';
import '../../features/offline_sync/data/datasources/sync_local_datasource.dart';
import '../../features/offline_sync/data/repositories/sync_repository_impl.dart';
import '../../features/offline_sync/domain/repositories/sync_repository.dart';
import '../../features/offline_sync/presentation/bloc/sync_bloc.dart';
import '../../features/gear_relay/data/repositories/gear_relay_repository_impl.dart';
import '../../features/gear_relay/data/services/image_compression_service.dart';
import '../../features/gear_relay/domain/repositories/gear_relay_repository.dart';
import '../../features/gear_relay/presentation/bloc/gear_relay_bloc.dart';

final sl = GetIt.instance;

/// Initializes all application-wide singletons, database helpers, and feature dependencies.
Future<void> initDependencies({bool enableHeartbeat = true}) async {
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
  initSignatureDependencies();
  initTelemetryDependencies(enableHeartbeat: enableHeartbeat);
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
  if (!sl.isRegistered<AuthBloc>()) {
    sl.registerFactory<AuthBloc>(
      () => AuthBloc(authRepository: sl<AuthRepository>()),
    );
  }
}

/// Feature DI: Underwriting & Quick Quote Calculator
void initQuoteDependencies() {
  if (!sl.isRegistered<QuoteRemoteDataSource>()) {
    sl.registerLazySingleton<QuoteRemoteDataSource>(
      () => QuoteRemoteDataSourceImpl(apiClient: sl<ApiClient>()),
    );
  }
  if (!sl.isRegistered<QuoteLocalDataSource>()) {
    sl.registerLazySingleton<QuoteLocalDataSource>(
      () => QuoteLocalDataSourceImpl(databaseHelper: sl<DatabaseHelper>()),
    );
  }
  if (!sl.isRegistered<QuoteRepository>()) {
    sl.registerLazySingleton<QuoteRepository>(
      () => QuoteRepositoryImpl(
        remoteDataSource: sl<QuoteRemoteDataSource>(),
        localDataSource: sl<QuoteLocalDataSource>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<GetAssetByBarcodeUseCase>()) {
    sl.registerLazySingleton<GetAssetByBarcodeUseCase>(
      () => GetAssetByBarcodeUseCase(sl<QuoteRepository>()),
    );
  }
  if (!sl.isRegistered<CalculateQuickQuoteUseCase>()) {
    sl.registerLazySingleton<CalculateQuickQuoteUseCase>(
      () => CalculateQuickQuoteUseCase(sl<QuoteRepository>()),
    );
  }
  if (!sl.isRegistered<QuoteBloc>()) {
    sl.registerFactory<QuoteBloc>(
      () => QuoteBloc(
        getAssetByBarcodeUseCase: sl<GetAssetByBarcodeUseCase>(),
        calculateQuickQuoteUseCase: sl<CalculateQuickQuoteUseCase>(),
      ),
    );
  }
}

/// Feature DI: Native Optical & Barcode Scanner
void initScannerDependencies() {
  if (!sl.isRegistered<ScannerBloc>()) {
    sl.registerFactory<ScannerBloc>(
      () => ScannerBloc(
        getAssetByBarcodeUseCase: sl<GetAssetByBarcodeUseCase>(),
      ),
    );
  }
}

/// Feature DI: Vector E-Signature on Glass
void initSignatureDependencies() {
  if (!sl.isRegistered<SignatureRepository>()) {
    sl.registerLazySingleton<SignatureRepository>(
      () => SignatureRepositoryImpl(
        apiClient: sl<ApiClient>(),
        databaseHelper: sl<DatabaseHelper>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<SignatureBloc>()) {
    sl.registerFactory<SignatureBloc>(
      () => SignatureBloc(
        signatureRepository: sl<SignatureRepository>(),
        biometricDataSource: sl<BiometricLocalDataSource>(),
      ),
    );
  }
}

/// Feature DI: Real-Time IoT Machine Telemetry
void initTelemetryDependencies({bool enableHeartbeat = true}) {
  if (!sl.isRegistered<TelemetryWsDataSource>()) {
    sl.registerLazySingleton<TelemetryWsDataSource>(
      () => TelemetryWsDataSourceImpl(enableHeartbeat: enableHeartbeat),
      dispose: (ds) => ds.dispose(),
    );
  }
  if (!sl.isRegistered<TelemetryRepository>()) {
    sl.registerLazySingleton<TelemetryRepository>(
      () => TelemetryRepositoryImpl(
        wsDataSource: sl<TelemetryWsDataSource>(),
        databaseHelper: sl<DatabaseHelper>(),
        apiClient: sl<ApiClient>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<TelemetryBloc>()) {
    sl.registerFactory<TelemetryBloc>(
      () => TelemetryBloc(
        telemetryRepository: sl<TelemetryRepository>(),
      ),
    );
  }
}

/// Feature DI: Offline-First Queue & Sync Engine
void initOfflineSyncDependencies() {
  if (!sl.isRegistered<SyncLocalDataSource>()) {
    sl.registerLazySingleton<SyncLocalDataSource>(
      () => SyncLocalDataSourceImpl(databaseHelper: sl<DatabaseHelper>()),
    );
  }
  if (!sl.isRegistered<SyncRepository>()) {
    sl.registerLazySingleton<SyncRepository>(
      () => SyncRepositoryImpl(
        localDataSource: sl<SyncLocalDataSource>(),
        apiClient: sl<ApiClient>(),
        networkInfo: sl<NetworkInfo>(),
      ),
    );
  }
  if (!sl.isRegistered<SyncBloc>()) {
    sl.registerFactory<SyncBloc>(
      () => SyncBloc(syncRepository: sl<SyncRepository>()),
    );
  }
}

/// Feature DI: GearRelay 4-Angle Return Inspection
void initGearRelayDependencies() {
  if (!sl.isRegistered<ImageCompressionService>()) {
    sl.registerLazySingleton<ImageCompressionService>(
      () => ImageCompressionServiceImpl(),
    );
  }
  if (!sl.isRegistered<GearRelayRepository>()) {
    sl.registerLazySingleton<GearRelayRepository>(
      () => GearRelayRepositoryImpl(
        apiClient: sl<ApiClient>(),
        databaseHelper: sl<DatabaseHelper>(),
        networkInfo: sl<NetworkInfo>(),
        compressionService: sl<ImageCompressionService>(),
      ),
    );
  }
  if (!sl.isRegistered<GearRelayBloc>()) {
    sl.registerFactory<GearRelayBloc>(
      () => GearRelayBloc(repository: sl<GearRelayRepository>()),
    );
  }
}

/// Test Hook: Resets GetIt instance for clean test execution
Future<void> resetDependencies() async {
  if (sl.isRegistered<TelemetryWsDataSource>()) {
    sl<TelemetryWsDataSource>().dispose();
  }
  await sl.reset();
}

/// Test Hook: Registers or overrides a mock instance for testing
void registerMock<T extends Object>(T mockInstance) {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
  sl.registerSingleton<T>(mockInstance);
}
