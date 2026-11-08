import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'security/ssl_pinning_validator.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService secureStorageService;
  final SslPinningValidator sslPinningValidator;

  ApiClient({
    Dio? dioClient,
    required this.secureStorageService,
    SslPinningValidator? validator,
    Future<bool> Function()? onRefreshToken,
    void Function()? onSessionTerminated,
    AppConfig? config,
  })  : sslPinningValidator = validator ??
            SslPinningValidator(
              isProduction: (config ?? AppConfig.instance).enableStrictSslPinning,
              allowedFingerprints: (config ?? AppConfig.instance).allowedSslFingerprints,
            ),
        dio = dioClient ??
            Dio(
              BaseOptions(
                baseUrl: const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: '',
                ).isNotEmpty
                    ? const String.fromEnvironment('API_BASE_URL')
                    : (config ?? AppConfig.instance).baseUrl,
              ),
            ) {
    dio.options.connectTimeout ??= const Duration(seconds: 15);
    dio.options.receiveTimeout ??= const Duration(seconds: 15);
    dio.options.headers.putIfAbsent('Content-Type', () => 'application/json');
    dio.options.headers.putIfAbsent('Accept', () => 'application/json');

    _setupInterceptors(
      onRefreshToken: onRefreshToken,
      onSessionTerminated: onSessionTerminated,
      enableVerboseLogging: (config ?? AppConfig.instance).enableVerboseLogging,
    );
  }

  void _setupInterceptors({
    Future<bool> Function()? onRefreshToken,
    void Function()? onSessionTerminated,
    bool enableVerboseLogging = false,
  }) {
    // 1. Idempotency Key Interceptor for mutating verbs
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final method = options.method.toUpperCase();
          if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
            options.headers.putIfAbsent(
              'Idempotency-Key',
              () => const Uuid().v4(),
            );
          }
          return handler.next(options);
        },
      ),
    );

    // 2. Auth Interceptor for Bearer & Device UUID injection + 401 handling
    dio.interceptors.add(
      AuthInterceptor(
        storageService: secureStorageService,
        onRefreshToken: onRefreshToken,
        onSessionTerminated: onSessionTerminated,
      ),
    );

    // 3. Retry Interceptor for network timeouts and 5xx errors
    dio.interceptors.add(
      RetryInterceptor(dio: dio),
    );

    // 4. Verbose Network Logging Interceptor (for dev/staging sandbox debugging)
    if (enableVerboseLogging) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }
}
