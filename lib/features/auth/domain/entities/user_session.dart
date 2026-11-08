import 'package:equatable/equatable.dart';

// ignore_for_file: constant_identifier_names

enum UserRole {
  LESSEE_OWNER,
  VENDOR_AGENT,
}

class UserSession extends Equatable {
  final String userId;
  final String email;
  final String fullName;
  final String organizationId;
  final UserRole role;
  final String deviceUuid;
  final bool biometricsEnabled;
  final String token;

  const UserSession({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.organizationId,
    required this.role,
    required this.deviceUuid,
    required this.biometricsEnabled,
    required this.token,
  });

  UserSession copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? organizationId,
    UserRole? role,
    String? deviceUuid,
    bool? biometricsEnabled,
    String? token,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      organizationId: organizationId ?? this.organizationId,
      role: role ?? this.role,
      deviceUuid: deviceUuid ?? this.deviceUuid,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      token: token ?? this.token,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        email,
        fullName,
        organizationId,
        role,
        deviceUuid,
        biometricsEnabled,
        token,
      ];
}
