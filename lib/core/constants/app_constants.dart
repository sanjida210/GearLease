class AppConstants {
  AppConstants._();

  static const String appName = 'GearLease Mobile';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String baseUrl = 'https://api.gearlease.com';
  static const String wsFleetTelemetryUrl = 'wss://api.gearlease.com/ws/fleet';

  // Underwrite limits
  static const int quickQuoteExpirySeconds = 900;
  static const int defaultTermMonths = 36;
  static const double defaultDownPayment = 0.0;

  // Offline Sync
  static const String syncDatabaseName = 'gearlease_sync.db';
  static const int syncDatabaseVersion = 1;
}
