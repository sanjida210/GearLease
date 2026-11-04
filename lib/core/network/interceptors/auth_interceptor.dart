import 'package:dio/dio.dart';
import '../../storage/secure_storage_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService storageService;
  final Future<bool> Function()? onRefreshToken;
  final void Function()? onSessionTerminated;

  AuthInterceptor({
    required this.storageService,
    this.onRefreshToken,
    this.onSessionTerminated,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storageService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final deviceUuid = await storageService.getOrCreateDeviceUuid();
    options.headers['X-Device-Id'] = deviceUuid;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      if (onRefreshToken != null) {
        final refreshed = await onRefreshToken!();
        if (refreshed) {
          final token = await storageService.getAuthToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          return handler.next(err);
        }
      }
      await storageService.clearAuth();
      onSessionTerminated?.call();
    }
    handler.next(err);
  }
}
