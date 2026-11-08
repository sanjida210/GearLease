import 'package:flutter_test/flutter_test.dart';
import 'package:gearlease/core/config/app_config.dart';
import 'package:gearlease/core/network/api_client.dart';
import 'package:gearlease/core/storage/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSecureStorageService mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    AppConfig.reset();
  });

  tearDown(() {
    AppConfig.reset();
  });

  group('Phase 30 — AppConfig & Flavor Configuration Tests', () {
    test('Dev Flavor has sandbox base URL, verbose logging, and debug banner enabled', () {
      const config = AppConfig.dev;

      expect(config.flavor, equals(AppFlavor.dev));
      expect(config.isDev, isTrue);
      expect(config.isStaging, isFalse);
      expect(config.isProd, isFalse);
      expect(config.baseUrl, equals('https://sandbox-api.gearlease.com'));
      expect(config.wsFleetTelemetryUrl, contains('sandbox-api'));
      expect(config.enableVerboseLogging, isTrue);
      expect(config.enableMockBankingWebview, isTrue);
      expect(config.enableStrictSslPinning, isFalse);
      expect(config.showDebugBanner, isTrue);
    });

    test('Staging Flavor has staging BFF URL, mock banking enabled, and crash reporting enabled', () {
      const config = AppConfig.staging;

      expect(config.flavor, equals(AppFlavor.staging));
      expect(config.isStaging, isTrue);
      expect(config.baseUrl, equals('https://staging-bff.gearlease.com'));
      expect(config.enableMockBankingWebview, isTrue);
      expect(config.enableVerboseLogging, isTrue);
      expect(config.enableStrictSslPinning, isFalse);
      expect(config.enableCrashReporting, isTrue);
      expect(config.showDebugBanner, isTrue);
    });

    test('Prod Flavor has production base URL, strict SSL pinning, crash reporting, and debug banner disabled', () {
      const config = AppConfig.prod;

      expect(config.flavor, equals(AppFlavor.prod));
      expect(config.isProd, isTrue);
      expect(config.baseUrl, equals('https://api.gearlease.com'));
      expect(config.wsFleetTelemetryUrl, equals('wss://api.gearlease.com/ws/fleet'));
      expect(config.enableVerboseLogging, isFalse);
      expect(config.enableMockBankingWebview, isFalse);
      expect(config.enableStrictSslPinning, isTrue);
      expect(config.allowedSslFingerprints.isNotEmpty, isTrue);
      expect(config.enableCrashReporting, isTrue);
      expect(config.showDebugBanner, isFalse);
    });

    test('AppConfig.initialize swaps singleton instance', () {
      expect(AppConfig.instance.flavor, equals(AppFlavor.dev)); // Default fallback

      AppConfig.initialize(AppConfig.prod);
      expect(AppConfig.instance.flavor, equals(AppFlavor.prod));

      AppConfig.initialize(AppConfig.staging);
      expect(AppConfig.instance.flavor, equals(AppFlavor.staging));
    });

    test('ApiClient configures verbose logging interceptor when dev flavor is active', () {
      final devClient = ApiClient(
        secureStorageService: mockSecureStorage,
        config: AppConfig.dev,
      );

      expect(devClient.dio.options.baseUrl, equals('https://sandbox-api.gearlease.com'));
      expect(devClient.sslPinningValidator.isProduction, isFalse);
    });

    test('ApiClient configures strict SSL pinning validator when prod flavor is active', () {
      final prodClient = ApiClient(
        secureStorageService: mockSecureStorage,
        config: AppConfig.prod,
      );

      expect(prodClient.dio.options.baseUrl, equals('https://api.gearlease.com'));
      expect(prodClient.sslPinningValidator.isProduction, isTrue);
      expect(prodClient.sslPinningValidator.allowedFingerprints.isNotEmpty, isTrue);
    });
  });
}
