import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/machine_telemetry.dart';
import '../../domain/entities/predictive_alert.dart';
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
  late TelemetryBloc _telemetryBloc;

  @override
  void initState() {
    super.initState();
    context.read<TelemetryBloc>().add(StartTelemetryStream(widget.assetId));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _telemetryBloc = context.read<TelemetryBloc>();
  }

  @override
  void dispose() {
    _telemetryBloc.add(const StopTelemetryStream());
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
          if (state is TelemetryLive && state.serviceBookedSuccessfully) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warranty service ticket dispatched. OEM technician assigned.'),
                backgroundColor: AppColors.performanceGreen,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TelemetryConnecting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.precisionCyan),
            );
          }

          if (state is TelemetryFault) {
            return Center(
              child: Text(
                state.error,
                style: const TextStyle(color: AppColors.criticalRed),
              ),
            );
          }

          if (state is TelemetryLive) {
            final telemetry = state.data;
            final history = state.history;
            final alerts = state.alerts;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Machine Title & Status Pill
                  _buildMachineHeader(telemetry),
                  const SizedBox(height: 16),

                  // Requirement 1: Top Live Gauges (RPM dial, thermal, vibration)
                  _buildTopLiveGauges(telemetry),
                  const SizedBox(height: 16),

                  // Requirement 2: Historical Trend Charts using fl_chart
                  _buildChartCard(history),
                  const SizedBox(height: 16),

                  // Requirement 3: Active Predictive Alerts Section
                  _buildPredictiveAlertsSection(context, alerts, telemetry),
                  const SizedBox(height: 16),

                  // Requirement 4: Action CTA
                  _buildActionCta(context, telemetry, state.isBookingService),
                ],
              ),
            );
          }

          if (state is TelemetryOffline) {
            final telemetry = state.cachedData;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCardElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.industrialAmber),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cloud_off, size: 16, color: AppColors.industrialAmber),
                        SizedBox(width: 8),
                        Text(
                          'OFFLINE CACHE — DISPLAYING LAST KNOWN TELEMETRY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.industrialAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildMachineHeader(telemetry),
                  const SizedBox(height: 16),
                  _buildTopLiveGauges(telemetry),
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
    final (statusColor, statusLabel) = switch (telemetry.status) {
      MachineStatus.warning => (AppColors.industrialAmber, 'WARNING'),
      MachineStatus.fault => (AppColors.criticalRed, 'CRITICAL'),
      MachineStatus.optimal => (AppColors.performanceGreen, 'OPTIMAL'),
    };

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

  /// Requirement 1: Top Live Gauges: RPM dial gauge, thermal reading, and vibration metric.
  Widget _buildTopLiveGauges(MachineTelemetry telemetry) {
    return Row(
      children: [
        // RPM Dial Gauge
        Expanded(child: _buildRpmDialGauge(telemetry)),
        const SizedBox(width: 8),

        // Thermal Reading Gauge
        Expanded(child: _buildThermalGauge(telemetry)),
        const SizedBox(width: 8),

        // Vibration Metric Gauge
        Expanded(child: _buildVibrationGauge(telemetry)),
      ],
    );
  }

  Widget _buildRpmDialGauge(MachineTelemetry telemetry) {
    final rpmFormatted = NumberFormat('#,##0').format(telemetry.rpm);
    final ratio = (telemetry.rpm / 3000.0).clamp(0.0, 1.0);

    return Container(
      key: const Key('rpm_dial_gauge'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'MOTOR RPM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 58,
            height: 58,
            child: CustomPaint(
              painter: _DialGaugePainter(
                valuePercent: ratio,
                trackColor: AppColors.surfaceCardElevated,
                progressColor: AppColors.cyanAccent,
              ),
              child: Center(
                child: Text(
                  rpmFormatted,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ledgerWhite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'RPM',
            style: TextStyle(fontSize: 10, color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildThermalGauge(MachineTelemetry telemetry) {
    final tempColor = telemetry.temperatureCelsius >= 85.0
        ? AppColors.criticalRed
        : (telemetry.temperatureCelsius >= 75.0
            ? AppColors.industrialAmber
            : AppColors.performanceGreen);

    final ratio = (telemetry.temperatureCelsius / 100.0).clamp(0.0, 1.0);

    return Container(
      key: const Key('thermal_reading_gauge'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'OPERATING TEMP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${telemetry.temperatureCelsius.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tempColor,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceCardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(tempColor),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Limit 95°C',
            style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildVibrationGauge(MachineTelemetry telemetry) {
    final vibColor = telemetry.vibrationG >= 1.0
        ? AppColors.criticalRed
        : (telemetry.vibrationG >= 0.60
            ? AppColors.industrialAmber
            : AppColors.performanceGreen);

    final ratio = (telemetry.vibrationG / 1.5).clamp(0.0, 1.0);

    return Container(
      key: const Key('vibration_metric_gauge'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'VIBRATION METRIC',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ledgerMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${telemetry.vibrationG.toStringAsFixed(2)} G',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: vibColor,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceCardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(vibColor),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Limit 1.00 G',
            style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted),
          ),
        ],
      ),
    );
  }

  /// Requirement 2: Historical Trend Charts using fl_chart
  /// - Real-time updating LineChart tracking Temperature (°C) vs. RPM over the last 60 minutes.
  /// - Custom styled tooltips and threshold guide lines (Red line at 95°C).
  Widget _buildChartCard(List<MachineTelemetry> history) {
    final spotsRpm = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value.rpm / 35.0).clamp(0.0, 110.0)); // normalized scale
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE TELEMETRY WAVEFORM (60 MIN)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerWhite,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.criticalRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.criticalRed, width: 0.8),
                ),
                child: const Text(
                  '95°C Threshold',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.criticalRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: AppColors.cyanAccent),
              SizedBox(width: 4),
              Text('Motor RPM (Scaled)', style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted)),
              SizedBox(width: 12),
              CircleAvatar(radius: 4, backgroundColor: AppColors.industrialAmber),
              SizedBox(width: 4),
              Text('Temperature (°C)', style: TextStyle(fontSize: 10, color: AppColors.ledgerMuted)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'Gathering telemetry data...',
                      style: TextStyle(color: AppColors.ledgerMuted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 110,
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
                      extraLinesData: ExtraLinesData(
                        extraLinesOnTop: true,
                        horizontalLines: [
                          HorizontalLine(
                            y: 95.0,
                            color: AppColors.criticalRed,
                            strokeWidth: 1.5,
                            dashArray: [6, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              labelResolver: (_) => '95°C Threshold',
                              style: const TextStyle(
                                color: AppColors.criticalRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.surfaceCardElevated,
                          tooltipBorder: const BorderSide(color: AppColors.neutralBorder),
                          tooltipRoundedRadius: 6,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final isTemp = spot.barIndex == 1;
                              final label = isTemp ? 'Temp: ${spot.y.toStringAsFixed(1)}°C' : 'RPM (Norm): ${spot.y.toStringAsFixed(0)}';
                              return LineTooltipItem(
                                label,
                                TextStyle(
                                  color: isTemp ? AppColors.industrialAmber : AppColors.cyanAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
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

  /// Requirement 3: Active Predictive Alerts Section: Alert list with severity pills and timestamp
  Widget _buildPredictiveAlertsSection(
    BuildContext context,
    List<PredictiveAlert> alerts,
    MachineTelemetry telemetry,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE PREDICTIVE ALERTS (${alerts.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.ledgerWhite,
                ),
              ),
              if (alerts.isNotEmpty)
                const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: AppColors.criticalRed),
                    SizedBox(width: 4),
                    Text(
                      'ATTENTION REQUIRED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.criticalRed,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isNotEmpty)
            ...alerts.map((alert) => _buildAlertItem(context, alert))
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCardElevated.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: AppColors.performanceGreen),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All telemetry parameters operating within normal safety limits.',
                      style: TextStyle(fontSize: 11, color: AppColors.ledgerMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, PredictiveAlert alert) {
    final (severityColor, severityLabel) = switch (alert.severity) {
      AlertSeverity.CRITICAL => (AppColors.criticalRed, 'CRITICAL'),
      AlertSeverity.HIGH => (AppColors.industrialAmber, 'HIGH'),
      AlertSeverity.MEDIUM => (AppColors.cyanAccent, 'MEDIUM'),
      AlertSeverity.LOW => (AppColors.performanceGreen, 'LOW'),
    };

    final formattedDate = DateFormat('MMM dd, HH:mm').format(alert.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: severityColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 10, color: AppColors.ledgerMuted),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    key: Key('acknowledge_alert_${alert.alertId}'),
                    onTap: () {
                      context.read<TelemetryBloc>().add(AcknowledgeAlert(alert.alertId));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: AppColors.ledgerMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.ledgerWhite,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            alert.description,
            style: const TextStyle(fontSize: 11, color: AppColors.ledgerMuted),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 13, color: severityColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  alert.suggestedAction,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: severityColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  /// Requirement 4: Action CTA: "Schedule Preventive Warranty Service"
  Widget _buildActionCta(
    BuildContext context,
    MachineTelemetry telemetry,
    bool isBooking,
  ) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        key: const Key('schedule_service_button'),
        onPressed: isBooking
            ? null
            : () {
                context.read<TelemetryBloc>().add(
                      TelemetryScheduleServiceRequested(
                        assetId: telemetry.assetId,
                        notes: 'Preventive service requested from diagnostics screen',
                      ),
                    );
              },
        icon: isBooking
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.scaffoldBackground,
                ),
              )
            : const Icon(Icons.build_circle_outlined, size: 20),
        label: const Text(
          'Schedule Preventive Warranty Service',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.precisionCyan,
          foregroundColor: AppColors.scaffoldBackground,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DialGaugePainter extends CustomPainter {
  final double valuePercent;
  final Color trackColor;
  final Color progressColor;

  _DialGaugePainter({
    required this.valuePercent,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 5;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * valuePercent.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialGaugePainter oldDelegate) {
    return oldDelegate.valuePercent != valuePercent ||
        oldDelegate.progressColor != progressColor;
  }
}
