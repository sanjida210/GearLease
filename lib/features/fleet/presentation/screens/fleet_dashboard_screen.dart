import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../telemetry/domain/entities/machine_telemetry.dart';
import '../../../telemetry/presentation/bloc/telemetry_bloc.dart';
import '../../../telemetry/presentation/bloc/telemetry_event.dart';
import '../../../telemetry/presentation/bloc/telemetry_state.dart';
import '../../../telemetry/presentation/screens/machine_diagnostics_screen.dart';

class FleetDashboardScreen extends StatefulWidget {
  final void Function(String assetId)? onNavigateToDiagnostics;

  const FleetDashboardScreen({
    super.key,
    this.onNavigateToDiagnostics,
  });

  @override
  State<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends State<FleetDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  late TelemetryBloc _telemetryBloc;
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';

  @override
  void initState() {
    super.initState();
    context.read<TelemetryBloc>().add(TelemetryFleetSubscribeRequested());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _telemetryBloc = context.read<TelemetryBloc>();
  }

  @override
  void dispose() {
    _telemetryBloc.add(const StopTelemetryStream());
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          'FLEET ASSET OVERVIEW',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.ledgerMuted),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<TelemetryBloc, TelemetryState>(
        builder: (context, state) {
          if (state is TelemetryConnecting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.precisionCyan),
            );
          }

          List<MachineTelemetry> fleet = [];
          if (state is TelemetryLive) {
            fleet = state.fleet.isNotEmpty ? state.fleet : [state.data];
          }

          final totalHours = fleet.fold<double>(0.0, (sum, m) => sum + m.operatingHours);
          final totalBillingCents = fleet.fold<int>(0, (sum, m) => sum + m.currentBillingCents);

          // Apply filters
          final filteredFleet = fleet.where((machine) {
            final matchesSearch = _searchQuery.isEmpty ||
                machine.assetId.toLowerCase().contains(_searchQuery) ||
                machine.machineName.toLowerCase().contains(_searchQuery) ||
                machine.category.toLowerCase().contains(_searchQuery);

            final matchesStatus = switch (_selectedStatusFilter) {
              'Optimal' => machine.status == MachineStatus.optimal,
              'Warning' => machine.status == MachineStatus.warning,
              'Critical' => machine.status == MachineStatus.fault,
              _ => true,
            };

            return matchesSearch && matchesStatus;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Requirement 1: Fleet Metrics Bar
                _buildFleetMetricsBar(fleet.length, totalHours, totalBillingCents),
                const SizedBox(height: 16),

                // Requirement 3: Filter & Search controls
                _buildSearchAndFilters(),
                const SizedBox(height: 16),

                // Section Title with active counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'MACHINES IN OPERATION (${filteredFleet.length}/${fleet.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: AppColors.ledgerMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: AppColors.performanceGreen),
                        SizedBox(width: 4),
                        Text(
                          'IOT ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.performanceGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Requirement 2 & 4: Machine Asset Cards
                if (filteredFleet.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32.0),
                    alignment: Alignment.center,
                    child: Text(
                      fleet.isEmpty
                          ? 'No active leased machinery found'
                          : 'No machinery matching "$_searchQuery" or filter',
                      style: const TextStyle(color: AppColors.ledgerMuted),
                    ),
                  )
                else
                  ...filteredFleet.map((machine) => _buildMachineCard(context, machine)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Requirement 1: Fleet Metrics Bar
  /// Total leased assets, active operating hours, total monthly payment forecast.
  Widget _buildFleetMetricsBar(int assetCount, double totalHours, int totalBillingCents) {
    final hoursFormatted = NumberFormat('#,##0.0').format(totalHours);
    final forecastFormatted = NumberFormat('#,##0.00').format(totalBillingCents / 100);

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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL LEASED ASSETS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.ledgerMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$assetCount',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ledgerWhite,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 36, width: 1, color: AppColors.neutralBorder),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE OPERATING HOURS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.ledgerMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$hoursFormatted hrs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 36, width: 1, color: AppColors.neutralBorder),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTHLY PAYMENT FORECAST',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.ledgerMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$$forecastFormatted',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.performanceGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Requirement 3: Filter & Search
  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input
        TextField(
          key: const Key('fleet_search_input'),
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          style: const TextStyle(color: AppColors.ledgerWhite, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by serial, make, or model...',
            hintStyle: const TextStyle(color: AppColors.ledgerMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: AppColors.ledgerMuted, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.ledgerMuted, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.neutralBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.neutralBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.precisionCyan),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', const Key('filter_chip_all')),
              const SizedBox(width: 8),
              _buildFilterChip('Optimal', const Key('filter_chip_optimal'), AppColors.performanceGreen),
              const SizedBox(width: 8),
              _buildFilterChip('Warning', const Key('filter_chip_warning'), AppColors.industrialAmber),
              const SizedBox(width: 8),
              _buildFilterChip('Critical', const Key('filter_chip_critical'), AppColors.criticalRed),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, Key key, [Color? dotColor]) {
    final isSelected = _selectedStatusFilter == label;
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedStatusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceCardElevated : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.precisionCyan : AppColors.neutralBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              CircleAvatar(radius: 3, backgroundColor: dotColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.ledgerWhite : AppColors.ledgerMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Requirement 2: Machine Asset Cards
  /// - Machine make, model, serial, and thumbnail.
  /// - Live status badge: "Optimal" (Green), "Warning" (Amber), or "Critical" (Red).
  /// - Real-time telemetry pills: Operating Hours, Current RPM, Temperature.
  /// - Next ACH Auto-Debit date and scheduled amount.
  Widget _buildMachineCard(BuildContext context, MachineTelemetry machine) {
    final (statusColor, statusText) = switch (machine.status) {
      MachineStatus.warning => (AppColors.industrialAmber, 'Warning'),
      MachineStatus.fault => (AppColors.criticalRed, 'Critical'),
      MachineStatus.optimal => (AppColors.performanceGreen, 'Optimal'),
    };

    final billingDollars = NumberFormat('#,##0.00').format(machine.currentBillingCents / 100);
    final hoursFormatted = NumberFormat('#,##0.0').format(machine.runningHours);
    final rpmFormatted = NumberFormat('#,##0').format(machine.rpm);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: machine.hasAlert ? statusColor.withValues(alpha: 0.6) : AppColors.neutralBorder,
          width: machine.hasAlert ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Requirement 4: Tap card to navigate to detailed Machine Diagnostics screen
          if (widget.onNavigateToDiagnostics != null) {
            widget.onNavigateToDiagnostics!(machine.assetId);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<TelemetryBloc>(),
                  child: MachineDiagnosticsScreen(assetId: machine.assetId),
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Thumbnail + Make/Model + Serial + Live Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Machine Thumbnail Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.neutralBorder),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing_outlined,
                      size: 24,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Make, Model & Serial
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          machine.machineName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ledgerWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${machine.category} • SN: ${machine.assetId}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ledgerMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Live Status Badge: "Optimal", "Warning", or "Critical"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Real-Time Telemetry Pills: Hours, RPM, Temperature
              Row(
                children: [
                  _buildTelemetryPill(
                    icon: Icons.timer_outlined,
                    label: '$hoursFormatted hrs',
                    color: AppColors.ledgerWhite,
                  ),
                  const SizedBox(width: 8),
                  _buildTelemetryPill(
                    icon: Icons.rotate_right,
                    label: '$rpmFormatted RPM',
                    color: AppColors.cyanAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildTelemetryPill(
                    icon: Icons.thermostat_outlined,
                    label: '${machine.temperatureCelsius.toStringAsFixed(1)}°C',
                    color: machine.temperatureCelsius >= 85.0
                        ? AppColors.criticalRed
                        : machine.temperatureCelsius >= 75.0
                            ? AppColors.industrialAmber
                            : AppColors.performanceGreen,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Next ACH Auto-Debit Date and Scheduled Amount
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.ledgerMuted),
                        SizedBox(width: 6),
                        Text(
                          'Next ACH Auto-Debit: Nov 15',
                          style: TextStyle(fontSize: 11, color: AppColors.ledgerMuted),
                        ),
                      ],
                    ),
                    Text(
                      '\$$billingDollars / mo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.performanceGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardElevated,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.neutralBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
