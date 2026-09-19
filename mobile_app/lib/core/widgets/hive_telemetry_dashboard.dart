import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../controllers/telemetry_alert_controller.dart';
import '../models/hive_telemetry_models.dart';
import '../theme/app_theme.dart';

/// Live hive telemetry dashboard fed ONLY by real backend data
/// (ESP32 -> MQTT -> AI/ML -> PostgreSQL -> REST).
///
/// States, in order of priority:
///  - Loading: spinner while the latest snapshot + history are fetched.
///  - Empty:   "Waiting for telemetry..." — no fabricated sensor values.
///  - Ready:   real sensor/diagnostic values plus the stored AI/ML result.
///  - Collecting: when the AI feature builder has not yet gathered the
///    ~145 readings (24 h at 10-minute sampling) it needs, honest progress
///    is shown instead of a fake analysis.
class HiveTelemetryDashboard extends StatefulWidget {
  final String hiveId;

  const HiveTelemetryDashboard({super.key, required this.hiveId});

  @override
  State<HiveTelemetryDashboard> createState() => _HiveTelemetryDashboardState();
}

class _HiveTelemetryDashboardState extends State<HiveTelemetryDashboard> {
  List<Map<String, dynamic>> _history = [];
  HiveSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ctrl = context.read<TelemetryAlertController>();
    final results = await Future.wait<dynamic>([
      ctrl.fetchHiveSnapshot(widget.hiveId),
      ctrl.fetchHiveTelemetry(widget.hiveId),
    ]);
    if (mounted) {
      setState(() {
        _snapshot = results[0] as HiveSnapshot?;
        _history = (results[1] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    }
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  /// Sensor values are shown ONLY from real backend data. Absent values
  /// render as '--' — never fabricated defaults.
  String _fmt(double? v, String unit, {int digits = 1}) {
    if (v == null) return '--$unit';
    return '${v.toStringAsFixed(digits)}$unit';
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'HEALTHY':
        return context.successColor;
      case 'ATTENTION':
        return context.warningColor;
      case 'ALERT':
        return AppConstants.error;
      default:
        return context.textMutedColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final telemetry = _snapshot?.telemetry;
    final ai = _snapshot?.aiStatus;
    final readiness = _snapshot?.aiReadiness;
    final hasTelemetry = _snapshot?.hasTelemetry ?? false;

    // Empty state: no real telemetry has arrived over MQTT yet. Show an
    // explicit waiting state — never placeholder sensor values.
    if (!hasTelemetry || telemetry == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.space16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.sensors_off_rounded, size: 28, color: context.textMutedColor),
            const SizedBox(height: 8),
            Text(
              'Waiting for telemetry...',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No telemetry available for this hive yet. Live sensor readings will appear here once the hive device starts publishing.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.space16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Latest real sensor values
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TelemetryStat(label: 'Temp', value: _fmt(telemetry.temperature, '°C')),
              _TelemetryStat(label: 'Humidity', value: _fmt(telemetry.humidity, '%')),
              _TelemetryStat(label: 'Weight', value: _fmt(telemetry.weightKg, ' kg', digits: 2)),
              _TelemetryStat(label: 'Acoustic', value: _fmt(telemetry.acousticsHz, ' Hz', digits: 0)),
            ],
          ),
          const SizedBox(height: 8),
          // Device diagnostics (real values when published)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TelemetryStat(label: 'Battery', value: _fmt(telemetry.batteryLevel, ' V', digits: 2)),
              _TelemetryStat(label: 'Wi-Fi', value: _fmt(telemetry.signalStrength, ' dBm', digits: 0)),
              _TelemetryStat(
                label: 'Updated',
                value: telemetry.recordedAt != null
                    ? _formatTime(telemetry.recordedAt!.toIso8601String())
                    : '--',
              ),
            ],
          ),

          const Divider(height: 24),

          // AI STATUS SECTION (from the existing AI/ML pipeline via the backend)
          if (ai != null) ...[
            Row(
              children: [
                Icon(Icons.psychology_alt_rounded, size: 16, color: _statusColor(ai.status)),
                const SizedBox(width: 6),
                Text(
                  'AI Analysis',
                  style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimaryColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(ai.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${ai.status ?? '--'} · Risk: ${ai.riskLevel ?? '--'}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(ai.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Anomaly: ${ai.anomalyDetected == true ? 'detected' : 'none'} · Score: ${ai.anomalyScore?.toStringAsFixed(4) ?? '--'}',
              style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
            ),
            for (final alert in ai.alerts.take(3)) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notification_important_rounded, size: 13, color: context.warningColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      alert['message']?.toString() ?? 'Hive alert.',
                      style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (readiness != null && !readiness.ready) ...[
            // The AI feature builder needs ~145 readings (24h at 10-minute
            // sampling). Show honest collection progress — never a fake result.
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, size: 16, color: context.textMutedColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Collecting telemetry history... (${readiness.currentReadings}/${readiness.requiredReadings} readings)',
                    style: GoogleFonts.inter(fontSize: 12, color: context.textSecondaryColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: readiness.progress,
                minHeight: 4,
                backgroundColor: context.borderColor.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI analysis will become available after sufficient history is collected.',
              style: GoogleFonts.inter(fontSize: 11, color: context.textMutedColor),
            ),
          ],

          const Divider(height: 24),

          // Actual historical telemetry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Temp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Hum', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
              Text('Weight', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSecondaryColor)),
            ],
          ),
          const Divider(height: 16),
          ..._history.take(7).map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 3, child: Text(_formatTime(entry['recordedAt']?.toString() ?? ''), style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor))),
                  Expanded(flex: 2, child: Text('${entry['temperature'] ?? '--'}°C', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimaryColor), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${entry['humidity'] ?? '--'}%', style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('${entry['weightKg'] ?? '--'}kg', style: GoogleFonts.inter(fontSize: 12, color: context.textPrimaryColor), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TelemetryStat extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textPrimaryColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: context.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}
