import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quote/domain/entities/hardware_asset.dart';
import '../../../quote/presentation/screens/quote_calculator_screen.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final ValueChanged<HardwareAsset>? onAssetResolved;
  final ValueChanged<String>? onBarcodeDetected;
  final VoidCallback? onNavigateToQuote;
  final bool? simulateDesktop;

  const BarcodeScannerScreen({
    super.key,
    this.onAssetResolved,
    this.onBarcodeDetected,
    this.onNavigateToQuote,
    this.simulateDesktop,
  });

  @override
  State<BarcodeScannerScreen> createState() => BarcodeScannerScreenState();
}

class BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController? _scannerController;
  final TextEditingController _manualInputController = TextEditingController();

  DateTime? lastScannedTimestamp;
  String? lastScannedCode;

  final List<Map<String, String>> mockBarcodes = const [
    {
      'code': 'CAT-320D-2024',
      'label': 'CAT 320D Excavator',
      'category': 'Heavy Earthmoving',
    },
    {
      'code': 'HAAS-VF2-CNC',
      'label': 'Haas VF-2 CNC Mill',
      'category': 'Precision Machining',
    },
    {
      'code': 'GL-ROAST-2026-9811',
      'label': 'La Marzocco Linea PB',
      'category': 'Commercial Espresso',
    },
    {
      'code': 'SYN-HYDRA-2026-4412',
      'label': 'Synesso MVP Hydra',
      'category': 'Commercial Espresso',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize native MobileScannerController on physical mobile platforms
    final isSimulated = widget.simulateDesktop ?? false;
    if (!isSimulated &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
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
        _handleSuccess(state.asset);
      }
    });
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  /// Scan throttling: rejects duplicate detections within 2 seconds.
  bool processBarcodeScan(String code) {
    final now = DateTime.now();
    if (lastScannedCode == code && lastScannedTimestamp != null) {
      final difference = now.difference(lastScannedTimestamp!).inMilliseconds;
      if (difference < 2000) {
        return false; // Throttled: duplicate detection within 2s
      }
    }

    lastScannedCode = code;
    lastScannedTimestamp = now;

    HapticFeedback.mediumImpact();
    widget.onBarcodeDetected?.call(code);
    context.read<ScannerBloc>().add(ScannerBarcodeDetected(code));
    return true;
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        if (processBarcodeScan(code.trim())) {
          break;
        }
      }
    }
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.lightImpact();
    try {
      await _scannerController?.toggleTorch();
    } catch (_) {
      // Gracefully handles uninitialized camera in test/desktop simulation
    }
    if (mounted) {
      context.read<ScannerBloc>().add(ScannerTorchToggled());
    }
  }

  Future<void> _flipCamera() async {
    HapticFeedback.lightImpact();
    try {
      await _scannerController?.switchCamera();
    } catch (_) {
      // Gracefully handles camera flip outside mobile hardware
    }
  }

  void _handleSuccess(HardwareAsset asset) {
    HapticFeedback.heavyImpact();
    widget.onAssetResolved?.call(asset);
    if (widget.onNavigateToQuote != null) {
      widget.onNavigateToQuote!();
    } else if (widget.onAssetResolved == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QuoteCalculatorScreen(),
        ),
      );
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
                  processBarcodeScan(text);
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
            key: const Key('scanner_flip_camera_button'),
            icon: const Icon(Icons.flip_camera_ios, color: AppColors.precisionCyan),
            onPressed: _flipCamera,
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
            _handleSuccess(state.asset);
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
              // Camera Viewfinder or Desktop Simulator Fallback
              if (_scannerController != null && !(widget.simulateDesktop ?? false))
                MobileScanner(
                  controller: _scannerController!,
                  onDetect: _onDetect,
                )
              else
                _buildDesktopSimulatorFallback(),

              // Custom Viewfinder Reticle Overlay with Industrial Green Corners (non-interactive HUD)
              IgnorePointer(
                child: Center(
                  child: _buildIndustrialViewfinderReticle(),
                ),
              ),

              // Bottom Instructional Status Pill
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: IgnorePointer(
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

  /// Custom Viewfinder Overlay with Industrial Green Targeting Corner Reticles
  Widget _buildIndustrialViewfinderReticle() {
    const cornerSize = 28.0;
    const cornerThickness = 4.0;
    const greenColor = AppColors.performanceGreen;

    return Container(
      key: const Key('scanner_viewfinder_reticle'),
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: greenColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Top-Left Industrial Green Corner Reticle
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: greenColor, width: cornerThickness),
                  left: BorderSide(color: greenColor, width: cornerThickness),
                ),
              ),
            ),
          ),
          // Top-Right Industrial Green Corner Reticle
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: greenColor, width: cornerThickness),
                  right: BorderSide(color: greenColor, width: cornerThickness),
                ),
              ),
            ),
          ),
          // Bottom-Left Industrial Green Corner Reticle
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: greenColor, width: cornerThickness),
                  left: BorderSide(color: greenColor, width: cornerThickness),
                ),
              ),
            ),
          ),
          // Bottom-Right Industrial Green Corner Reticle
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: greenColor, width: cornerThickness),
                  right: BorderSide(color: greenColor, width: cornerThickness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop / Simulator Fallback Viewport with Mock Barcode Selection
  Widget _buildDesktopSimulatorFallback() {
    return Container(
      color: const Color(0xFF070B11),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 56,
                  color: AppColors.performanceGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'OPTICAL SIMULATOR ACTIVE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.ledgerWhite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select simulated hardware asset or enter code manually',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.ledgerMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Barcode Action Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ActionChip(
                      key: const Key('mock_chip_cat'),
                      label: Text(
                        'CAT-320D-2024',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ledgerWhite,
                        ),
                      ),
                      backgroundColor: AppColors.surfaceCardElevated,
                      side: const BorderSide(color: AppColors.precisionCyan),
                      onPressed: () => processBarcodeScan('CAT-320D-2024'),
                    ),
                    ActionChip(
                      key: const Key('mock_chip_haas'),
                      label: Text(
                        'HAAS-VF2-CNC',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ledgerWhite,
                        ),
                      ),
                      backgroundColor: AppColors.surfaceCardElevated,
                      side: const BorderSide(color: AppColors.performanceGreen),
                      onPressed: () => processBarcodeScan('HAAS-VF2-CNC'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dropdown fallback selector
                DropdownButtonFormField<String>(
                  key: const Key('debug_mock_barcode_dropdown'),
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceCardElevated,
                  style: GoogleFonts.inter(color: AppColors.ledgerWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Select Mock Barcode',
                    labelStyle: GoogleFonts.inter(color: AppColors.ledgerMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceCardElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.neutralBorder),
                    ),
                  ),
                  items: mockBarcodes.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['code'],
                      child: Text(
                        '${item['code']} (${item['label']})',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.ledgerWhite),
                      ),
                    );
                  }).toList(),
                  onChanged: (code) {
                    if (code != null) {
                      processBarcodeScan(code);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
