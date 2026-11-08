import '../../domain/entities/user_session.dart';

class UserSessionModel extends UserSession {
  const UserSessionModel({
    required super.userId,
    required super.email,
    required super.fullName,
    required super.organizationId,
    required super.role,
    required super.deviceUuid,
    required super.biometricsEnabled,
    required super.token,
  });

  factory UserSessionModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String? ?? '').toUpperCase();
    final role = roleStr == 'VENDOR_AGENT'
        ? UserRole.VENDOR_AGENT
        : UserRole.LESSEE_OWNER;

    return UserSessionModel(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      organizationId: json['organization_id'] as String? ?? json['organizationId'] as String? ?? '',
      role: role,
      deviceUuid: json['device_uuid'] as String? ?? json['deviceUuid'] as String? ?? '',
      biometricsEnabled: json['biometrics_enabled'] as bool? ??
          json['biometricsEnabled'] as bool? ??
          false,
      token: json['token'] as String? ?? json['access_token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'organization_id': organizationId,
      'role': role == UserRole.VENDOR_AGENT ? 'VENDOR_AGENT' : 'LESSEE_OWNER',
      'device_uuid': deviceUuid,
      'biometrics_enabled': biometricsEnabled,
      'token': token,
    };
  }
}
