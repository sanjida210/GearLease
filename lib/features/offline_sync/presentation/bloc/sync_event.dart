import 'package:equatable/equatable.dart';
import '../../domain/entities/sync_item.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncWatchStarted extends SyncEvent {}

class SyncPendingCountUpdated extends SyncEvent {
  final int count;

  const SyncPendingCountUpdated(this.count);

  @override
  List<Object?> get props => [count];
}

class SyncTriggered extends SyncEvent {}

class EnqueueSyncItem extends SyncEvent {
  final SyncItem item;

  const EnqueueSyncItem(this.item);

  @override
  List<Object?> get props => [item];
}

class SyncConnectivityRestored extends SyncEvent {}
