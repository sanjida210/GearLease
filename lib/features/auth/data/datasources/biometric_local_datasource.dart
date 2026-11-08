import 'package:local_auth/local_auth.dart';
import '../../../../core/error/exceptions.dart';

abstract class BiometricLocalDataSource {
  Future<bool> isBiometricsAvailable();
  Future<bool> authenticate({required String reason});
}

class BiometricLocalDataSourceImpl implements BiometricLocalDataSource {
  final LocalAuthentication _localAuth;

  BiometricLocalDataSourceImpl({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return authenticated;
    } catch (e) {
      throw BiometricException('Biometric authentication failed: $e');
    }
  }
}
