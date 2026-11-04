import 'dart:math';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Random _random = Random();

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 1.5,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final currentAttempt = requestOptions.extra['retry_attempt'] as int? ?? 0;

    final shouldRetry = _isRetryable(err) && currentAttempt < maxRetries;

    if (shouldRetry) {
      final nextAttempt = currentAttempt + 1;
      requestOptions.extra['retry_attempt'] = nextAttempt;

      final delayMs = (initialDelay.inMilliseconds * pow(backoffMultiplier, currentAttempt)).toInt();
      final jitterMs = _random.nextInt(max(1, delayMs ~/ 2 + 1));
      await Future.delayed(Duration(milliseconds: delayMs + jitterMs));

      try {
        final response = await dio.fetch(requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }

    handler.next(err);
  }

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = err.response?.statusCode;
    if (status != null && status >= 500 && status <= 599) {
      return true;
    }
    return false;
  }
}
