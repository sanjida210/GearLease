import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

class OfflineSyncBanner extends StatelessWidget {
  final bool? isOffline;

  const OfflineSyncBanner({
    super.key,
    this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        final offlineMode = isOffline ?? false;
        if (!offlineMode && state.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final isSyncing = state is SyncRunning;

        String bannerText;
        if (offlineMode) {
          bannerText = isSyncing
              ? 'Syncing queue — Flushing ${state.pendingCount} actions...'
              : 'Offline Mode — ${state.pendingCount} Actions Queued for Sync';
        } else {
          bannerText = isSyncing
              ? 'Syncing queue — Flushing ${state.pendingCount} actions...'
              : 'OFFLINE QUEUE: ${state.pendingCount} PENDING RECORDS';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.industrialAmber.withValues(alpha: 0.18),
            border: const Border(
              bottom: BorderSide(color: AppColors.industrialAmber, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              if (isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.industrialAmber,
                  ),
                )
              else
                const Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: AppColors.industrialAmber,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bannerText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.industrialAmber,
                  ),
                ),
              ),
              if (!isSyncing && state.pendingCount > 0)
                TextButton(
                  key: const Key('offline_sync_now_button'),
                  onPressed: () {
                    context.read<SyncBloc>().add(SyncTriggered());
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.industrialAmber,
                    foregroundColor: AppColors.scaffoldBackground,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'SYNC NOW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
