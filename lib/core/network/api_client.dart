import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService secureStorageService;

  ApiClient({
    Dio? dioClient,
    required this.secureStorageService,
  }) : dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorageService.getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final deviceUuid = await secureStorageService.getOrCreateDeviceUuid();
          options.headers['X-Device-Id'] = deviceUuid;

          // Attach Idempotency-Key if not explicitly provided for mutating POST/PUT requests
          if (options.method == 'POST' || options.method == 'PUT') {
            options.headers.putIfAbsent(
              'Idempotency-Key',
              () => const Uuid().v4(),
            );
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Centralized Dio error handling
          return handler.next(error);
        },
      ),
    );
  }
}
