class ServerException implements Exception {
  final String message;
  final int? statusCode;
  ServerException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network connection failed']);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
