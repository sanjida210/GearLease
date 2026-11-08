import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../fleet/presentation/screens/fleet_dashboard_screen.dart';
import '../../../gear_relay/presentation/screens/gear_relay_guide_screen.dart';
import '../../../offline_sync/presentation/widgets/offline_sync_banner.dart';
import '../../../quote/presentation/bloc/quote_bloc.dart';
import '../../../quote/presentation/bloc/quote_event.dart';
import '../../../quote/presentation/screens/quote_calculator_screen.dart';
import '../../../scanner/presentation/screens/barcode_scanner_screen.dart';
import '../../../signature/presentation/bloc/signature_bloc.dart';
import '../../../signature/presentation/widgets/signature_pad_modal.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _openBarcodeScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.surfaceCard,
            title: const Text('SCAN MACHINE BARCODE'),
          ),
          body: BarcodeScannerScreen(
            onAssetResolved: (asset) {
              context.read<QuoteBloc>().add(LookupAssetRequested(asset.serialNumber));
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _openSignaturePad(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: BlocProvider.value(
          value: context.read<SignatureBloc>(),
          child: SignaturePadModal(
            contractId: 'ctr-882201',
            onSigned: (signEvent) {
              Navigator.of(bottomSheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lease Agreement executed and funded successfully!'),
                  backgroundColor: AppColors.performanceGreen,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return const FleetDashboardScreen();
      case 1:
        return Stack(
          children: [
            QuoteCalculatorScreen(
              onProceedToSignature: () => _openSignaturePad(context),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                key: const Key('vendor_scan_fab'),
                onPressed: () => _openBarcodeScanner(context),
                backgroundColor: AppColors.precisionCyan,
                foregroundColor: AppColors.scaffoldBackground,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'SCAN ASSET',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      case 2:
        return const GearRelayGuideScreen(assetId: 'ast_probat12');
      default:
        return const FleetDashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 720;

    if (isTablet) {
      return Scaffold(
        body: Column(
          children: [
            const OfflineSyncBanner(),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    backgroundColor: AppColors.surfaceCard,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.precisionCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.precisionCyan),
                            ),
                            child: const Icon(
                              Icons.precision_manufacturing_rounded,
                              color: AppColors.precisionCyan,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'GEARLEASE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.precisionCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.precision_manufacturing_outlined),
                        selectedIcon: Icon(Icons.precision_manufacturing, color: AppColors.cyanAccent),
                        label: Text('Fleet'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.qr_code_scanner_outlined),
                        selectedIcon: Icon(Icons.qr_code_scanner, color: AppColors.cyanAccent),
                        label: Text('Vendor POS'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.autorenew_outlined),
                        selectedIcon: Icon(Icons.autorenew, color: AppColors.cyanAccent),
                        label: Text('Repayments'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: AppColors.neutralBorder),
                  Expanded(child: _buildCurrentTab()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineSyncBanner(),
            Expanded(child: _buildCurrentTab()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surfaceCard,
        selectedItemColor: AppColors.cyanAccent,
        unselectedItemColor: AppColors.ledgerMuted,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.precision_manufacturing_outlined),
            activeIcon: Icon(Icons.precision_manufacturing),
            label: 'Fleet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'Vendor POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.autorenew_outlined),
            activeIcon: Icon(Icons.autorenew),
            label: 'Repayments',
          ),
        ],
      ),
    );
  }
}
