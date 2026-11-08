import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/sync_repository.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository syncRepository;
  StreamSubscription<int>? _countSubscription;

  SyncBloc({required this.syncRepository}) : super(const SyncInitial()) {
    on<SyncWatchStarted>(_onWatchStarted);
    on<SyncPendingCountUpdated>(_onPendingCountUpdated);
    on<SyncTriggered>(_onSyncTriggered);
    on<EnqueueSyncItem>(_onEnqueueSyncItem);
    on<SyncConnectivityRestored>(_onConnectivityRestored);
  }

  Future<void> _onWatchStarted(
    SyncWatchStarted event,
    Emitter<SyncState> emit,
  ) async {
    await _countSubscription?.cancel();
    _countSubscription = syncRepository.watchPendingCount().listen(
          (count) => add(SyncPendingCountUpdated(count)),
        );
  }

  void _onPendingCountUpdated(
    SyncPendingCountUpdated event,
    Emitter<SyncState> emit,
  ) {
    emit(SyncIdle(event.count));
  }

  Future<void> _onSyncTriggered(
    SyncTriggered event,
    Emitter<SyncState> emit,
  ) async {
    emit(SyncRunning(state.pendingCount));
    await syncRepository.syncAllPending();
    final updatedCount = await syncRepository.getPendingCount();
    emit(SyncIdle(updatedCount));
  }

  Future<void> _onEnqueueSyncItem(
    EnqueueSyncItem event,
    Emitter<SyncState> emit,
  ) async {
    await syncRepository.enqueueRequest(event.item);
    final count = await syncRepository.getPendingCount();
    emit(SyncIdle(count));
  }

  Future<void> _onConnectivityRestored(
    SyncConnectivityRestored event,
    Emitter<SyncState> emit,
  ) async {
    emit(SyncRunning(state.pendingCount));
    await syncRepository.processSyncQueue();
    final updatedCount = await syncRepository.getPendingCount();
    emit(SyncIdle(updatedCount));
  }

  @override
  Future<void> close() {
    _countSubscription?.cancel();
    return super.close();
  }
}
