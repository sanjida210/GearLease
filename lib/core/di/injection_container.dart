import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../storage/secure_storage_service.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  // Core Storage & Network
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(storage: sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(secureStorageService: sl<SecureStorageService>()),
  );
}
