import 'package:equatable/equatable.dart';

enum UserRole { lesseeOwner, vendorAgent, admin }

class UserSession extends Equatable {
  final String userId;
  final String email;
  final String displayName;
  final String organizationId;
  final String organizationName;
  final UserRole role;
  final bool isBiometricActive;

  const UserSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    this.isBiometricActive = false,
  });

  @override
  List<Object?> get props => [
        userId,
        email,
        displayName,
        organizationId,
        organizationName,
        role,
        isBiometricActive,
      ];
}
