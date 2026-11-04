import 'package:equatable/equatable.dart';

enum SyncStatus { pending, syncing, synced, failed }

class SyncItem extends Equatable {
  final String id;
  final String idempotencyKey;
  final String actionType;
  final String payloadJson;
  final List<String> filePaths;
  final SyncStatus status;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String? errorMessage;

  const SyncItem({
    required this.id,
    required this.idempotencyKey,
    required this.actionType,
    required this.payloadJson,
    this.filePaths = const [],
    this.status = SyncStatus.pending,
    required this.createdAt,
    this.syncedAt,
    this.errorMessage,
  });

  SyncItem copyWith({
    SyncStatus? status,
    DateTime? syncedAt,
    String? errorMessage,
  }) {
    return SyncItem(
      id: id,
      idempotencyKey: idempotencyKey,
      actionType: actionType,
      payloadJson: payloadJson,
      filePaths: filePaths,
      status: status ?? this.status,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        id,
        idempotencyKey,
        actionType,
        payloadJson,
        filePaths,
        status,
        createdAt,
        syncedAt,
        errorMessage,
      ];
}
