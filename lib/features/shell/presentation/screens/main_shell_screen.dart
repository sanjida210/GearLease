import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_session.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
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
  final UserRole? userRole;
  final int? initialIndex;
  final bool isOffline;

  const MainShellScreen({
    super.key,
    this.userRole,
    this.initialIndex,
    this.isOffline = false,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    } else if (widget.userRole == UserRole.VENDOR_AGENT) {
      _currentIndex = 1; // Showroom Agent lands on Vendor POS
    } else if (widget.userRole == UserRole.LESSEE_OWNER) {
      _currentIndex = 0; // Lessee lands on Fleet Dashboard
    } else {
      // Check active auth session if available
      try {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated &&
            authState.session.role == UserRole.VENDOR_AGENT) {
          _currentIndex = 1;
        } else {
          _currentIndex = 0;
        }
      } catch (_) {
        _currentIndex = 0;
      }
    }
  }

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
      case 3:
        return _buildSettingsTab(context);
      default:
        return const FleetDashboardScreen();
    }
  }

  Widget _buildSettingsTab(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          'SETTINGS & PREFERENCES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User & Role Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutralBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.precisionCyan.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.precisionCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Authenticated Session',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ledgerWhite,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userRole == UserRole.VENDOR_AGENT
                            ? 'Role: Showroom Agent (Vendor POS Landing)'
                            : 'Role: Industrial Lessee (Fleet Overview Landing)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Preferences Group
          Material(
            color: AppColors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.neutralBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.fingerprint, color: AppColors.precisionCyan),
                  title: Text('Biometric Authentication', style: TextStyle(color: AppColors.ledgerWhite, fontSize: 13)),
                  subtitle: Text('FaceID / TouchID for Sign-on-Glass execution', style: TextStyle(color: AppColors.ledgerMuted, fontSize: 11)),
                  trailing: Icon(Icons.check_circle, color: AppColors.performanceGreen, size: 18),
                ),
                const Divider(height: 1, color: AppColors.neutralBorder),
                const ListTile(
                  leading: Icon(Icons.cloud_sync, color: AppColors.industrialAmber),
                  title: Text('Offline Sync Engine', style: TextStyle(color: AppColors.ledgerWhite, fontSize: 13)),
                  subtitle: Text('Background SQLite Queue & Workmanager Enabled', style: TextStyle(color: AppColors.ledgerMuted, fontSize: 11)),
                  trailing: Icon(Icons.chevron_right, color: AppColors.ledgerMuted),
                ),
                const Divider(height: 1, color: AppColors.neutralBorder),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.criticalRed),
                  title: const Text('Sign Out', style: TextStyle(color: AppColors.criticalRed, fontSize: 13, fontWeight: FontWeight.bold)),
                  onTap: () {
                    try {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Version Footer
          const Center(
            child: Text(
              'GearLease v2.4.0 (Enterprise Precision Build)',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.ledgerMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 720;

    if (isTablet) {
      return Scaffold(
        body: Column(
          children: [
            OfflineSyncBanner(isOffline: widget.isOffline),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    backgroundColor: AppColors.surfaceCard,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                    },
                    extended: true,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.precisionCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.precisionCyan),
                            ),
                            child: const Icon(
                              Icons.precision_manufacturing_rounded,
                              color: AppColors.precisionCyan,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'GEARLEASE',
                            style: TextStyle(
                              fontSize: 12,
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
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale, color: AppColors.cyanAccent),
                        label: Text('Vendor POS'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.autorenew_outlined),
                        selectedIcon: Icon(Icons.autorenew, color: AppColors.cyanAccent),
                        label: Text('Repayments'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings, color: AppColors.cyanAccent),
                        label: Text('Settings'),
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
            OfflineSyncBanner(isOffline: widget.isOffline),
            Expanded(child: _buildCurrentTab()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Vendor POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.autorenew_outlined),
            activeIcon: Icon(Icons.autorenew),
            label: 'Repayments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
