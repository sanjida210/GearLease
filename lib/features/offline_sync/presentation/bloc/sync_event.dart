import 'package:equatable/equatable.dart';

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
