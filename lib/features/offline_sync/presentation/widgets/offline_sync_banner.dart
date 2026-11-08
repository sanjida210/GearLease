import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        if (state.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final isSyncing = state is SyncRunning;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.industrialAmber.withValues(alpha: 0.15),
            border: const Border(
              bottom: BorderSide(color: AppColors.industrialAmber, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off,
                size: 16,
                color: AppColors.industrialAmber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OFFLINE QUEUE: ${state.pendingCount} PENDING RECORDS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.industrialAmber,
                  ),
                ),
              ),
              TextButton(
                key: const Key('offline_sync_now_button'),
                onPressed: isSyncing
                    ? null
                    : () {
                        context.read<SyncBloc>().add(SyncTriggered());
                      },
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.industrialAmber,
                  foregroundColor: AppColors.scaffoldBackground,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: isSyncing
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.scaffoldBackground,
                        ),
                      )
                    : const Text(
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
