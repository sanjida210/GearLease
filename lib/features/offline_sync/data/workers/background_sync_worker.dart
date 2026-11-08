import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/sync_repository.dart';

const String backgroundSyncTaskKey = 'com.gearlease.background_sync';
const String backgroundPeriodicSyncTag = 'gearlease_periodic_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == backgroundSyncTaskKey || taskName == Workmanager.iOSBackgroundTask) {
        initDependencies();
        final syncRepository = sl<SyncRepository>();
        await syncRepository.processSyncQueue();
      }
      return true;
    } catch (e) {
      debugPrint('BackgroundSyncWorker error: $e');
      return false;
    }
  });
}

class BackgroundSyncWorker {
  final Workmanager workmanager;

  BackgroundSyncWorker({Workmanager? workmanager})
      : workmanager = workmanager ?? Workmanager();

  Future<void> initialize({
    bool isInDebugMode = false,
    bool forcePlatformSupport = false,
  }) async {
    final isSupported = forcePlatformSupport ||
        (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS));

    if (isSupported) {
      await workmanager.initialize(
        callbackDispatcher,
        isInDebugMode: isInDebugMode,
      );
    }
  }

  Future<void> registerPeriodicSync({
    Duration frequency = const Duration(minutes: 15),
    bool forcePlatformSupport = false,
  }) async {
    final isSupported = forcePlatformSupport ||
        (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS));

    if (isSupported) {
      await workmanager.registerPeriodicTask(
        backgroundSyncTaskKey,
        backgroundSyncTaskKey,
        frequency: frequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        tag: backgroundPeriodicSyncTag,
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    }
  }

  Future<void> cancelAll() async {
    await workmanager.cancelAll();
  }
}
