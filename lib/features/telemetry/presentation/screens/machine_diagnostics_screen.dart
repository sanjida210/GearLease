import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../bloc/telemetry_bloc.dart';
import '../bloc/telemetry_event.dart';
import '../bloc/telemetry_state.dart';

class MachineDiagnosticsScreen extends StatefulWidget {
  final String assetId;

  const MachineDiagnosticsScreen({
    super.key,
    required this.assetId,
  });

  @override
  State<MachineDiagnosticsScreen> createState() => _MachineDiagnosticsScreenState();
}

class _MachineDiagnosticsScreenState extends State<MachineDiagnosticsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TelemetryBloc>().add(TelemetrySubscribeRequested(widget.assetId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
        title: const Text(
          'IOT MACHINE DIAGNOSTICS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCardElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.neutralBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 14, color: AppColors.performanceGreen),
                SizedBox(width: 4),
                Text(
                  'LIVE STREAM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.performanceGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocConsumer<TelemetryBloc, TelemetryState>(
        listener: (context, state) {
          if (state is TelemetryStreaming && state.serviceBookedSuccessfully) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warranty service ticket dispatched. OEM technician assigned.'),
                backgroundColor: AppColors.performanceGreen,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TelemetryLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.precisionCyan),
            );
          }

          if (state is TelemetryError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: AppColors.criticalRed),
              ),
            );
          }

          if (state is TelemetryStreaming && state.latest != null) {
            final telemetry = state.latest!;
            final history = state.history;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Machine Title & Status Pill
                  _buildMachineHeader(telemetry),
                  const SizedBox(height: 16),

                  // Metrics Row (Hours, Temp, RPM)
                  _buildMetricsRow(telemetry),
                  const SizedBox(height: 16),

                  // Real-Time Line Chart
                  _buildChartCard(history),
                  const SizedBox(height: 16),

                  // Alert Banner & Booking CTA
                  if (telemetry.hasAlert)
                    _buildAlertBanner(context, telemetry, state.isBookingService),
                ],
              ),
            );
          }

          return const Center(
            child: Text(
              'Awaiting machine telemetry stream...',
              style: TextStyle(color: AppColors.ledgerMuted),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMachineHeader(MachineTelemetry telemetry) {
    Color statusColor;
    String statusLabel;
    switch (telemetry.status) {
      case MachineStatus.warning:
        statusColor = AppColors.industrialAmber;
        statusLabel = 'WARNING';
        break;
      case MachineStatus.fault:
        statusColor = AppColors.criticalRed;
        statusLabel = 'FAULT';
        break;
      case MachineStatus.optimal:
        statusColor = AppColors.performanceGreen;
        statusLabel = 'OPTIMAL';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  telemetry.machineName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ledgerWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${telemetry.category} • Asset: ${telemetry.assetId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.ledgerMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(MachineTelemetry telemetry) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'MOTOR RPM',
            value: telemetry.motorRpm.toStringAsFixed(0),
            unit: 'rpm',
            color: AppColors.cyanAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'OPERATING TEMP',
            value: telemetry.temperatureCelsius.toStringAsFixed(1),
            unit: '°C',
            color: telemetry.temperatureCelsius >= 75.0
                ? AppColors.industrialAmber
                : AppColors.performanceGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricTile(
            label: 'RUNNING HOURS',
            value: telemetry.runningHours.toStringAsFixed(1),
            unit: 'hrs',
            color: AppColors.ledgerWhite,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.ledgerMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<MachineTelemetry> history) {
    final spotsRpm = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.motorRpm / 20.0); // scaled down for normalized graph
    }).toList();

    final spotsTemp = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.temperatureCelsius);
    }).toList();

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE TELEMETRY WAVEFORM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerWhite,
                ),
              ),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: AppColors.cyanAccent),
                  SizedBox(width: 4),
                  Text('RPM/20', style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted)),
                  SizedBox(width: 8),
                  CircleAvatar(radius: 4, backgroundColor: AppColors.industrialAmber),
                  SizedBox(width: 4),
                  Text('Temp °C', style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: history.isEmpty
                ? const Center(child: Text('Gathering telemetry data...'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: AppColors.surfaceCardElevated,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: const FlTitlesData(
                        show: false,
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spotsRpm,
                          isCurved: true,
                          color: AppColors.cyanAccent,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: spotsTemp,
                          isCurved: true,
                          color: AppColors.industrialAmber,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(
    BuildContext context,
    MachineTelemetry telemetry,
    bool isBooking,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.industrialAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.industrialAmber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.industrialAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operating temperature (${telemetry.temperatureCelsius.toStringAsFixed(1)}°C) exceeds baseline.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.industrialAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Predictive diagnostics indicate potential thermal throttling. Service is fully covered under your GearLease Master Warranty.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const Key('schedule_service_button'),
            onPressed: isBooking
                ? null
                : () {
                    context.read<TelemetryBloc>().add(
                          TelemetryScheduleServiceRequested(
                            assetId: telemetry.assetId,
                            notes: 'Thermal alert: ${telemetry.temperatureCelsius}°C',
                          ),
                        );
                  },
            icon: isBooking
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.scaffoldBackground),
                  )
                : const Icon(Icons.build, size: 16),
            label: const Text('SCHEDULE COVERED WARRANTY SERVICE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.industrialAmber,
              foregroundColor: AppColors.scaffoldBackground,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
