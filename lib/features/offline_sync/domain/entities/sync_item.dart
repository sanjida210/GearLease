// ignore_for_file: constant_identifier_names

import 'package:equatable/equatable.dart';

enum SyncItemStatus {
  queued('QUEUED'),
  processing('PROCESSING'),
  synced('SYNCED'),
  conflictRejected('CONFLICT_REJECTED');

  final String code;
  const SyncItemStatus(this.code);

  static const SyncItemStatus QUEUED = SyncItemStatus.queued;
  static const SyncItemStatus PROCESSING = SyncItemStatus.processing;
  static const SyncItemStatus SYNCED = SyncItemStatus.synced;
  static const SyncItemStatus CONFLICT_REJECTED = SyncItemStatus.conflictRejected;

  // Compatibility aliases
  static const SyncItemStatus pending = SyncItemStatus.queued;
  static const SyncItemStatus syncing = SyncItemStatus.processing;
  static const SyncItemStatus failed = SyncItemStatus.conflictRejected;

  static SyncItemStatus fromString(String value) {
    final upper = value.toUpperCase().trim();
    for (final status in SyncItemStatus.values) {
      if (status.code == upper || status.name.toUpperCase() == upper) {
        return status;
      }
    }
    if (upper == 'PENDING') return SyncItemStatus.queued;
    if (upper == 'SYNCING') return SyncItemStatus.processing;
    if (upper == 'FAILED') return SyncItemStatus.conflictRejected;
    return SyncItemStatus.queued;
  }
}

typedef SyncStatus = SyncItemStatus;

class SyncItem extends Equatable {
  final String id;
  final String endpoint;
  final String httpMethod;
  final String payloadJson;
  final List<String> mediaFilePaths;
  final SyncItemStatus status;
  final int retryCount;
  final DateTime createdAt;
  final String idempotencyKey;
  final DateTime? syncedAt;
  final String? errorMessage;

  const SyncItem({
    required this.id,
    String? endpoint,
    String? actionType,
    this.httpMethod = 'POST',
    required this.payloadJson,
    List<String>? mediaFilePaths,
    List<String>? filePaths,
    this.status = SyncItemStatus.QUEUED,
    this.retryCount = 0,
    required this.createdAt,
    required this.idempotencyKey,
    this.syncedAt,
    this.errorMessage,
  })  : endpoint = endpoint ?? actionType ?? '',
        mediaFilePaths = mediaFilePaths ?? filePaths ?? const [];

  // Compatibility getters
  String get actionType => endpoint;
  List<String> get filePaths => mediaFilePaths;

  SyncItem copyWith({
    String? id,
    String? endpoint,
    String? httpMethod,
    String? payloadJson,
    List<String>? mediaFilePaths,
    SyncItemStatus? status,
    int? retryCount,
    DateTime? createdAt,
    String? idempotencyKey,
    DateTime? syncedAt,
    String? errorMessage,
  }) {
    return SyncItem(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      httpMethod: httpMethod ?? this.httpMethod,
      payloadJson: payloadJson ?? this.payloadJson,
      mediaFilePaths: mediaFilePaths ?? this.mediaFilePaths,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      syncedAt: syncedAt ?? this.syncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'endpoint': endpoint,
      'http_method': httpMethod,
      'payload_json': payloadJson,
      'media_file_paths': mediaFilePaths,
      'status': status.code,
      'retry_count': retryCount,
      'created_at': createdAt.toIso8601String(),
      'idempotency_key': idempotencyKey,
      if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      id: json['id'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? json['action_type'] as String? ?? '',
      httpMethod: json['http_method'] as String? ?? json['method'] as String? ?? 'POST',
      payloadJson: json['payload_json'] as String? ?? json['payload'] as String? ?? '{}',
      mediaFilePaths: json['media_file_paths'] != null
          ? List<String>.from(json['media_file_paths'] as List)
          : (json['file_paths'] != null
              ? List<String>.from(json['file_paths'] as List)
              : const []),
      status: SyncItemStatus.fromString(
        json['status'] as String? ?? 'QUEUED',
      ),
      retryCount: json['retry_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? (json['created_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
              : DateTime.parse(json['created_at'] as String))
          : DateTime.now(),
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        endpoint,
        httpMethod,
        payloadJson,
        mediaFilePaths,
        status,
        retryCount,
        createdAt,
        idempotencyKey,
        syncedAt,
        errorMessage,
      ];
}
