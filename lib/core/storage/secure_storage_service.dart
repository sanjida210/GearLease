import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyDeviceUuid = 'device_uuid';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<String> getOrCreateDeviceUuid() async {
    String? uuid = await _storage.read(key: _keyDeviceUuid);
    if (uuid == null) {
      uuid = const Uuid().v4();
      await _storage.write(key: _keyDeviceUuid, value: uuid);
    }
    return uuid;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
  }

  Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyRefreshToken);
  }
}
