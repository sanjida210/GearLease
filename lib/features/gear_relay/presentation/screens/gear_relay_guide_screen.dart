import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/inspection_angle.dart';
import '../bloc/gear_relay_bloc.dart';
import '../bloc/gear_relay_event.dart';
import '../bloc/gear_relay_state.dart';

class GearRelayGuideScreen extends StatefulWidget {
  final String assetId;
  final ImagePicker? imagePicker;

  const GearRelayGuideScreen({
    super.key,
    required this.assetId,
    this.imagePicker,
  });

  @override
  State<GearRelayGuideScreen> createState() => _GearRelayGuideScreenState();
}

class _GearRelayGuideScreenState extends State<GearRelayGuideScreen> {
  late final ImagePicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    context.read<GearRelayBloc>().add(GearRelayStarted(widget.assetId));
  }

  Future<void> _capturePhoto(int angleIndex) async {
    try {
      String? path;
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
        final photo = await _picker.pickImage(source: ImageSource.camera);
        path = photo?.path;
      } else {
        // Desktop / Test mock fallback path
        path = '/mock/storage/gear_relay_${widget.assetId}_angle_$angleIndex.jpg';
      }

      if (path != null && mounted) {
        context.read<GearRelayBloc>().add(
              GearRelayPhotoCaptured(
                angleIndex: angleIndex,
                imagePath: path,
              ),
            );
      }
    } catch (_) {
      if (mounted) {
        context.read<GearRelayBloc>().add(
              GearRelayPhotoCaptured(
                angleIndex: angleIndex,
                imagePath: '/mock/storage/gear_relay_fallback.jpg',
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          'GEARRELAY RETURN GUIDE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: BlocConsumer<GearRelayBloc, GearRelayState>(
        listener: (context, state) {
          if (state is GearRelayActive && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is! GearRelayActive) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.precisionCyan),
            );
          }

          if (state.completedValuationId != null) {
            return _buildSuccessView(context, state);
          }

          final currentAngle = state.currentAngle;
          final allDone = state.allAnglesCaptured;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4-Angle Progress Tabs
                _buildAngleTabs(state),
                const SizedBox(height: 16),

                // AR Silhouette Viewfinder Frame
                _buildViewfinderFrame(currentAngle),
                const SizedBox(height: 16),

                // Angle Instruction Box
                _buildInstructionBox(currentAngle),
                const SizedBox(height: 20),

                // Primary Capture Action
                ElevatedButton.icon(
                  key: const Key('capture_angle_button'),
                  onPressed: () => _capturePhoto(state.currentAngleIndex),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    currentAngle.isCaptured
                        ? 'RETAKE ${currentAngle.title.toUpperCase()}'
                        : 'CAPTURE ${currentAngle.title.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.precisionCyan,
                    foregroundColor: AppColors.scaffoldBackground,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // Submit Valuation Bundle CTA
                if (allDone) ...[
                  ElevatedButton(
                    key: const Key('submit_bundle_button'),
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            context.read<GearRelayBloc>().add(
                                  GearRelaySubmitRequested(widget.assetId),
                                );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.performanceGreen,
                      foregroundColor: AppColors.scaffoldBackground,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.scaffoldBackground,
                            ),
                          )
                        : const Text(
                            'SUBMIT CPO INSPECTION BUNDLE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAngleTabs(GearRelayActive state) {
    return Row(
      children: state.angles.asMap().entries.map((entry) {
        final index = entry.key;
        final angle = entry.value;
        final isSelected = index == state.currentAngleIndex;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<GearRelayBloc>().add(GearRelayAngleSelected(index));
            },
            child: Container(
              margin: EdgeInsets.only(right: index < state.angles.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surfaceCardElevated : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.precisionCyan
                      : (angle.isCaptured ? AppColors.performanceGreen : AppColors.neutralBorder),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    angle.isCaptured ? Icons.check_circle : Icons.camera_outlined,
                    size: 16,
                    color: angle.isCaptured
                        ? AppColors.performanceGreen
                        : (isSelected ? AppColors.precisionCyan : AppColors.ledgerMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.ledgerWhite : AppColors.ledgerMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildViewfinderFrame(InspectionAngle angle) {
    IconData silhouetteIcon;
    String overlayLabel;

    switch (angle.type) {
      case InspectionAngleType.serialTag:
        silhouetteIcon = Icons.qr_code_scanner;
        overlayLabel = 'SERIAL TAG & BARCODE OVERLAY';
        break;
      case InspectionAngleType.engineHousing:
        silhouetteIcon = Icons.settings;
        overlayLabel = 'MOTOR & ENGINE HOUSING OVERLAY';
        break;
      case InspectionAngleType.controlDisplay:
        silhouetteIcon = Icons.speed;
        overlayLabel = 'DIGITAL HOUR METER OVERLAY';
        break;
      case InspectionAngleType.frontProfile:
        silhouetteIcon = Icons.crop_free;
        overlayLabel = 'FRONT PROFILE SILHOUETTE';
        break;
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: angle.isCaptured ? AppColors.performanceGreen : AppColors.precisionCyan,
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background AR Silhouette representation
          Opacity(
            opacity: 0.15,
            child: Icon(
              silhouetteIcon,
              size: 120,
              color: AppColors.cyanAccent,
            ),
          ),
          // Viewfinder Target Frame
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.cyanAccent.withValues(alpha: 0.5),
                style: BorderStyle.solid,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                overlayLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.cyanAccent,
                ),
              ),
            ),
          ),
          if (angle.isCaptured)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.performanceGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.performanceGreen),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, size: 12, color: AppColors.performanceGreen),
                    SizedBox(width: 4),
                    Text(
                      'CAPTURED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.performanceGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionBox(InspectionAngle angle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            angle.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.ledgerWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            angle.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.ledgerMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, GearRelayActive state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.performanceGreen),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 64,
                color: AppColors.performanceGreen,
              ),
              const SizedBox(height: 16),
              const Text(
                'INSPECTION BUNDLE SUBMITTED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerWhite,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Valuation Ticket: ${state.completedValuationId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.cyanAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'AI vision assessment is processing your machine return. Guaranteed Certified Pre-Owned (CPO) credit will appear in your Repayments portal within 5 minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ledgerMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.precisionCyan,
                  foregroundColor: AppColors.scaffoldBackground,
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text(
                  'RETURN TO FLEET',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
