import 'dart:io';
import 'package:crypto/crypto.dart';

class SslPinningValidator {
  final List<String> allowedFingerprints;
  final bool isProduction;

  const SslPinningValidator({
    this.allowedFingerprints = const [],
    this.isProduction = false,
  });

  /// Validates an X509Certificate during TLS handshake.
  /// Falls back to true in debug / non-production mode.
  bool validateCertificate(X509Certificate? cert, String host, int port) {
    if (!isProduction) {
      // Local debugging / staging automated fallback
      return true;
    }
    if (cert == null) return false;
    final certSha256 = sha256.convert(cert.der).toString();
    return validateFingerprint(certSha256);
  }

  /// Checks if a given SHA-256 fingerprint matches allowed hashes.
  bool validateFingerprint(String sha256Fingerprint) {
    if (!isProduction) {
      return true;
    }
    return allowedFingerprints.contains(sha256Fingerprint);
  }
}
