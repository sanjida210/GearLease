import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _PlaceholderTab(
      title: 'Active Fleet Supervision',
      subtitle: 'Real-time telemetry, operating hours & diagnostics',
      icon: Icons.precision_manufacturing_outlined,
    ),
    const _PlaceholderTab(
      title: 'Vendor Showroom POS',
      subtitle: 'Scan equipment barcodes & instant credit underwrite',
      icon: Icons.qr_code_scanner_rounded,
    ),
    const _PlaceholderTab(
      title: 'Dynamic Repayments',
      subtitle: 'Revenue-indexed ACH ledger & seasonal payment flexing',
      icon: Icons.account_balance_wallet_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppColors.surfaceCard,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.precisionCyan.withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.precisionCyan),
                      ),
                      child: const Icon(
                        Icons.build_circle_outlined,
                        color: AppColors.precisionCyan,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GEARLEASE',
                      style: TextStyle(
                        fontSize: 11,
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
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet, color: AppColors.cyanAccent),
                  label: Text('Repayments'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, color: AppColors.cardBorder),
            Expanded(child: _tabs[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
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
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Repayments',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.surfaceCardElevated,
              child: Text(
                'GL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyanAccent),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Icon(icon, size: 48, color: AppColors.precisionCyan),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
