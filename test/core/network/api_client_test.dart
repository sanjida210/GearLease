import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/network/interceptors/auth_interceptor.dart';
import 'package:gearlease/core/network/interceptors/retry_interceptor.dart';
import 'package:gearlease/core/network/security/ssl_pinning_validator.dart';
import 'package:gearlease/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late SecureStorageService secureStorageService;
  late Dio testDio;
  late MockHttpClientAdapter mockAdapter;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    secureStorageService = SecureStorageService(storage: mockStorage);
    testDio = Dio();
    mockAdapter = MockHttpClientAdapter();
    testDio.httpClientAdapter = mockAdapter;

    when(() => mockStorage.read(key: 'device_uuid'))
        .thenAnswer((_) async => 'mock-device-uuid-1234');
    when(() => mockStorage.read(key: 'auth_token'))
        .thenAnswer((_) async => 'mock-jwt-token');
  });

  group('ApiClient Setup & Configuration', () {
    test('initializes with 15s connect and receive timeouts', () {
      final client = ApiClient(
        dioClient: testDio,
        secureStorageService: secureStorageService,
      );

      expect(client.dio.options.connectTimeout, const Duration(seconds: 15));
      expect(client.dio.options.receiveTimeout, const Duration(seconds: 15));
    });

    test('injects Idempotency-Key header for POST, PUT, and PATCH', () async {
      final client = ApiClient(
        dioClient: testDio,
        secureStorageService: secureStorageService,
      );

      mockAdapterResponse(mockAdapter, 200, {'status': 'ok'});

      final postResponse = await client.dio.post('/test-post');
      expect(postResponse.requestOptions.headers['Idempotency-Key'], isNotNull);

      final putResponse = await client.dio.put('/test-put');
      expect(putResponse.requestOptions.headers['Idempotency-Key'], isNotNull);

      final patchResponse = await client.dio.patch('/test-patch');
      expect(patchResponse.requestOptions.headers['Idempotency-Key'], isNotNull);

      final getResponse = await client.dio.get('/test-get');
      expect(getResponse.requestOptions.headers['Idempotency-Key'], isNull);
    });

    test('injects Bearer token and X-Device-Id from SecureStorage', () async {
      final client = ApiClient(
        dioClient: testDio,
        secureStorageService: secureStorageService,
      );

      mockAdapterResponse(mockAdapter, 200, {'data': 'secure'});

      final response = await client.dio.get('/secure-data');

      expect(response.requestOptions.headers['Authorization'], 'Bearer mock-jwt-token');
      expect(response.requestOptions.headers['X-Device-Id'], 'mock-device-uuid-1234');
    });
  });

  group('AuthInterceptor Tests', () {
    test('clears auth token and calls onSessionTerminated on 401 response', () async {
      bool sessionTerminated = false;
      when(() => mockStorage.delete(key: 'auth_token')).thenAnswer((_) async {});
      when(() => mockStorage.delete(key: 'refresh_token')).thenAnswer((_) async {});

      final authInterceptor = AuthInterceptor(
        storageService: secureStorageService,
        onSessionTerminated: () => sessionTerminated = true,
      );

      final dio = Dio();
      dio.interceptors.add(authInterceptor);
      final adapter = MockHttpClientAdapter();
      dio.httpClientAdapter = adapter;

      when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/unauthorized'),
          response: Response(
            requestOptions: RequestOptions(path: '/unauthorized'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      try {
        await dio.get('/unauthorized');
      } catch (_) {}

      expect(sessionTerminated, isTrue);
      verify(() => mockStorage.delete(key: 'auth_token')).called(1);
    });
  });

  group('RetryInterceptor Tests', () {
    test('retries on 500 error up to maxRetries', () async {
      int attempts = 0;
      final dio = Dio();
      final retryInterceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 2,
        initialDelay: const Duration(milliseconds: 10),
      );
      dio.interceptors.add(retryInterceptor);

      final adapter = MockHttpClientAdapter();
      dio.httpClientAdapter = adapter;

      when(() => adapter.fetch(any(), any(), any())).thenAnswer((invocation) async {
        attempts++;
        if (attempts <= 2) {
          throw DioException(
            requestOptions: invocation.positionalArguments[0] as RequestOptions,
            response: Response(
              requestOptions: invocation.positionalArguments[0] as RequestOptions,
              statusCode: 500,
            ),
            type: DioExceptionType.badResponse,
          );
        }
        return ResponseBody.fromString('{"recovered": true}', 200);
      });

      final response = await dio.get('/flaky');
      expect(response.statusCode, 200);
      expect(attempts, 3); // initial attempt + 2 retries
    });
  });

  group('SslPinningValidator Tests', () {
    test('allows any certificate in debug / non-production mode', () {
      const validator = SslPinningValidator(isProduction: false);
      expect(validator.validateCertificate(null, 'api.gearlease.com', 443), isTrue);
    });

    test('rejects null certificate in production mode', () {
      const validator = SslPinningValidator(
        isProduction: true,
        allowedFingerprints: ['valid-sha256-hash'],
      );
      expect(validator.validateCertificate(null, 'api.gearlease.com', 443), isFalse);
    });

    test('validates matching SHA-256 fingerprint in production mode', () {
      const validator = SslPinningValidator(
        isProduction: true,
        allowedFingerprints: ['expected-fingerprint-abc'],
      );
      expect(
        validator.validateFingerprint('expected-fingerprint-abc'),
        isTrue,
      );
      expect(
        validator.validateFingerprint('unrecognized-fingerprint'),
        isFalse,
      );
    });
  });
}

void mockAdapterResponse(
  MockHttpClientAdapter adapter,
  int statusCode,
  Map<String, dynamic> data,
) {
  when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });
}
