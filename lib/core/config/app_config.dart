enum AppFlavor { dev, staging, prod }

class AppConfig {
  final AppFlavor flavor;
  final String appTitle;
  final String baseUrl;
  final String wsFleetTelemetryUrl;
  final bool enableVerboseLogging;
  final bool enableMockBankingWebview;
  final bool enableStrictSslPinning;
  final List<String> allowedSslFingerprints;
  final bool enableCrashReporting;
  final bool showDebugBanner;

  static AppConfig? _instance;

  const AppConfig._({
    required this.flavor,
    required this.appTitle,
    required this.baseUrl,
    required this.wsFleetTelemetryUrl,
    required this.enableVerboseLogging,
    required this.enableMockBankingWebview,
    required this.enableStrictSslPinning,
    this.allowedSslFingerprints = const [],
    required this.enableCrashReporting,
    required this.showDebugBanner,
  });

  static AppConfig get instance {
    _instance ??= dev;
    return _instance!;
  }

  static void initialize(AppConfig config) {
    _instance = config;
  }

  static void reset() {
    _instance = null;
  }

  static const AppConfig dev = AppConfig._(
    flavor: AppFlavor.dev,
    appTitle: 'GearLease (Dev Sandbox)',
    baseUrl: 'https://sandbox-api.gearlease.com',
    wsFleetTelemetryUrl: 'wss://sandbox-api.gearlease.com/ws/fleet',
    enableVerboseLogging: true,
    enableMockBankingWebview: true,
    enableStrictSslPinning: false,
    allowedSslFingerprints: [],
    enableCrashReporting: false,
    showDebugBanner: true,
  );

  static const AppConfig staging = AppConfig._(
    flavor: AppFlavor.staging,
    appTitle: 'GearLease (Staging BFF)',
    baseUrl: 'https://staging-bff.gearlease.com',
    wsFleetTelemetryUrl: 'wss://staging-bff.gearlease.com/ws/fleet',
    enableVerboseLogging: true,
    enableMockBankingWebview: true,
    enableStrictSslPinning: false,
    allowedSslFingerprints: [],
    enableCrashReporting: true,
    showDebugBanner: true,
  );

  static const AppConfig prod = AppConfig._(
    flavor: AppFlavor.prod,
    appTitle: 'GearLease',
    baseUrl: 'https://api.gearlease.com',
    wsFleetTelemetryUrl: 'wss://api.gearlease.com/ws/fleet',
    enableVerboseLogging: false,
    enableMockBankingWebview: false,
    enableStrictSslPinning: true,
    allowedSslFingerprints: [
      '2C:3B:4E:91:78:E2:B0:9C:5F:8B:E3:42:0E:54:3D:11:7F:32:8A:2B:9E:C1:F4:77:2D:E8:11:2C:4B:9A:80:55',
    ],
    enableCrashReporting: true,
    showDebugBanner: false,
  );

  bool get isDev => flavor == AppFlavor.dev;
  bool get isStaging => flavor == AppFlavor.staging;
  bool get isProd => flavor == AppFlavor.prod;
}
