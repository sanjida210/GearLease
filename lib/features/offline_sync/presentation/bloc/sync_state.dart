import 'package:equatable/equatable.dart';

abstract class SyncState extends Equatable {
  final int pendingCount;

  const SyncState({this.pendingCount = 0});

  @override
  List<Object?> get props => [pendingCount];
}

class SyncInitial extends SyncState {
  const SyncInitial() : super(pendingCount: 0);
}

class SyncIdle extends SyncState {
  const SyncIdle(int pendingCount) : super(pendingCount: pendingCount);
}

class SyncRunning extends SyncState {
  const SyncRunning(int pendingCount) : super(pendingCount: pendingCount);
}
