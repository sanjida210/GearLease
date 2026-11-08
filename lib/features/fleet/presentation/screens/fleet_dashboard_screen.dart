import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<TelemetryBloc>().add(TelemetryFleetSubscribeRequested());
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
          if (state is TelemetryLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.precisionCyan),
            );
          }

          List<MachineTelemetry> fleet = [];
          if (state is TelemetryStreaming) {
            fleet = state.fleet.isNotEmpty ? state.fleet : (state.latest != null ? [state.latest!] : []);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Financial Overview
                _buildFinancialOverviewCard(),
                const SizedBox(height: 20),

                // Machines Section Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MACHINES IN OPERATION (${fleet.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.ledgerMuted,
                      ),
                    ),
                    const Row(
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

                // Asset Cards
                if (fleet.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No active leased machinery found',
                        style: TextStyle(color: AppColors.ledgerMuted),
                      ),
                    ),
                  )
                else
                  ...fleet.map((machine) => _buildMachineCard(context, machine)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinancialOverviewCard() {
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
          const Text(
            'PORTFOLIO REPAYMENT SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CAPITAL COMMITTED',
                      style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '\$118,500',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ledgerWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 Leased Assets',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.cyanAccent.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 45,
                width: 1,
                color: AppColors.neutralBorder,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT ACH DEDUCTION',
                      style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$2,290.00',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.performanceGreen,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Due Nov 15 • Auto-Debit',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ledgerMuted,
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

  Widget _buildMachineCard(BuildContext context, MachineTelemetry machine) {
    Color statusColor;
    String statusText;
    switch (machine.status) {
      case MachineStatus.warning:
        statusColor = AppColors.industrialAmber;
        statusText = 'WARNING';
        break;
      case MachineStatus.fault:
        statusColor = AppColors.criticalRed;
        statusText = 'FAULT';
        break;
      case MachineStatus.optimal:
        statusColor = AppColors.performanceGreen;
        statusText = 'OPTIMAL';
        break;
    }

    final billingDollars = (machine.currentBillingCents / 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: machine.hasAlert ? statusColor : AppColors.neutralBorder,
          width: machine.hasAlert ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          machine.machineName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ledgerWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          machine.category,
                          style: const TextStyle(fontSize: 12, color: AppColors.ledgerMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hours: ${machine.runningHours.toStringAsFixed(1)} hrs',
                    style: const TextStyle(fontSize: 12, color: AppColors.ledgerWhite),
                  ),
                  Text(
                    'Temp: ${machine.temperatureCelsius.toStringAsFixed(1)}°C',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: machine.temperatureCelsius >= 75.0
                          ? AppColors.industrialAmber
                          : AppColors.performanceGreen,
                    ),
                  ),
                  Text(
                    'Billing: \$$billingDollars/mo',
                    style: const TextStyle(fontSize: 12, color: AppColors.cyanAccent),
                  ),
                ],
              ),
              if (machine.hasAlert) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.industrialAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.industrialAmber),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Schedule covered warranty service >',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.industrialAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
