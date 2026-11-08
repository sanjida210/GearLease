import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quote/domain/entities/hardware_asset.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final ValueChanged<HardwareAsset>? onAssetResolved;

  const BarcodeScannerScreen({
    super.key,
    this.onAssetResolved,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _scannerController;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Only initialize native MobileScannerController on actual mobile platforms
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
    context.read<ScannerBloc>().add(ScannerStartRequested());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<ScannerBloc>().state;
      if (state is ScannerSuccess) {
        widget.onAssetResolved?.call(state.asset);
      }
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        HapticFeedback.mediumImpact();
        context.read<ScannerBloc>().add(ScannerBarcodeDetected(code));
        break;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController?.toggleTorch();
    } catch (_) {
      // Gracefully handles uninitialized camera in test/desktop simulation
    }
    if (mounted) {
      context.read<ScannerBloc>().add(ScannerTorchToggled());
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text(
            'MANUAL ASSET LOOKUP',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ledgerWhite,
            ),
          ),
          content: TextField(
            key: const Key('manual_barcode_input'),
            controller: _manualInputController,
            style: GoogleFonts.inter(color: AppColors.ledgerWhite),
            decoration: InputDecoration(
              hintText: 'Enter barcode or VIN...',
              hintStyle: GoogleFonts.inter(color: AppColors.ledgerMuted),
              filled: true,
              fillColor: AppColors.surfaceCardElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.neutralBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'CANCEL',
                style: GoogleFonts.inter(color: AppColors.ledgerMuted),
              ),
            ),
            ElevatedButton(
              key: const Key('manual_resolve_button'),
              onPressed: () {
                final text = _manualInputController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  context.read<ScannerBloc>().add(ScannerBarcodeDetected(text));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.precisionCyan,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'RESOLVE ASSET',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          'OPTICAL ASSET SCANNER',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.ledgerWhite,
          ),
        ),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('scanner_torch_button'),
            icon: const Icon(Icons.flash_on, color: AppColors.precisionCyan),
            onPressed: _toggleTorch,
          ),
          IconButton(
            key: const Key('scanner_manual_entry_button'),
            icon: const Icon(Icons.keyboard, color: AppColors.ledgerWhite),
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerSuccess) {
            widget.onAssetResolved?.call(state.asset);
          } else if (state is ScannerFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
        },
        builder: (context, state) {
          final isProcessing = state is ScannerProcessing;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera Viewfinder or Simulated Canvas
              if (_scannerController != null)
                MobileScanner(
                  controller: _scannerController!,
                  onDetect: _onDetect,
                )
              else
                Container(
                  color: const Color(0xFF070B11),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 72,
                          color: AppColors.precisionCyan.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'OPTICAL VIEWPORT ACTIVE',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.ledgerMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // HUD Viewfinder Reticle Overlay
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.precisionCyan.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // HUD Corner accents
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.cyanAccent, width: 4),
                              left: BorderSide(color: AppColors.cyanAccent, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.cyanAccent, width: 4),
                              right: BorderSide(color: AppColors.cyanAccent, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.cyanAccent, width: 4),
                              left: BorderSide(color: AppColors.cyanAccent, width: 4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.cyanAccent, width: 4),
                              right: BorderSide(color: AppColors.cyanAccent, width: 4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Instructional Pill
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.neutralBorder),
                    ),
                    child: Text(
                      'ALIGN CODE 128 / QR ON EQUIPMENT PLATE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: AppColors.ledgerWhite,
                      ),
                    ),
                  ),
                ),
              ),

              // Loading overlay
              if (isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.precisionCyan),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
