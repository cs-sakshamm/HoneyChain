/// Read-only view models for real hive telemetry data served by the FastAPI
/// backend (MQTT -> AI/ML -> PostgreSQL -> REST). No fabricated defaults:
/// every field is nullable because absence of data must be visible in the UI.
class HiveTelemetrySample {
  final String? deviceId;
  final int? timestamp;
  final double? temperature;
  final double? humidity;
  final double? weightKg;
  final double? acousticsHz;
  final double? batteryLevel;
  final double? signalStrength;
  final DateTime? recordedAt;

  const HiveTelemetrySample({
    this.deviceId,
    this.timestamp,
    this.temperature,
    this.humidity,
    this.weightKg,
    this.acousticsHz,
    this.batteryLevel,
    this.signalStrength,
    this.recordedAt,
  });

  factory HiveTelemetrySample.fromJson(Map<String, dynamic> json) {
    return HiveTelemetrySample(
      deviceId: json['deviceId']?.toString(),
      timestamp: (json['timestamp'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      acousticsHz: (json['acousticsHz'] as num?)?.toDouble(),
      batteryLevel: (json['batteryLevel'] as num?)?.toDouble(),
      signalStrength: (json['signalStrength'] as num?)?.toDouble(),
      recordedAt: json['recordedAt'] != null
          ? DateTime.tryParse(json['recordedAt'].toString())
          : null,
    );
  }
}

/// AI/ML hive status as produced by the existing Isolation Forest + risk
/// engine pipeline and stored by the backend.
class HiveAiStatus {
  final String? riskLevel; // LOW, MEDIUM, HIGH
  final String? status; // HEALTHY, ATTENTION, ALERT
  final bool? anomalyDetected;
  final double? anomalyScore;
  final String? temperatureStatus;
  final String? humidityStatus;
  final String? weightStatus;
  final String? weightTrend;
  final String? acousticStatus;
  final List<String> reasons;
  final List<Map<String, dynamic>> alerts;

  const HiveAiStatus({
    this.riskLevel,
    this.status,
    this.anomalyDetected,
    this.anomalyScore,
    this.temperatureStatus,
    this.humidityStatus,
    this.weightStatus,
    this.weightTrend,
    this.acousticStatus,
    this.reasons = const [],
    this.alerts = const [],
  });

  factory HiveAiStatus.fromJson(Map<String, dynamic> json) {
    return HiveAiStatus(
      riskLevel: json['riskLevel']?.toString(),
      status: json['status']?.toString(),
      anomalyDetected: json['anomalyDetected'] as bool?,
      anomalyScore: (json['anomalyScore'] as num?)?.toDouble(),
      temperatureStatus: json['temperatureStatus']?.toString(),
      humidityStatus: json['humidityStatus']?.toString(),
      weightStatus: json['weightStatus']?.toString(),
      weightTrend: json['weightTrend']?.toString(),
      acousticStatus: json['acousticStatus']?.toString(),
      reasons: (json['reasons'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

/// Progress toward the first complete AI analysis. The AI feature builder
/// needs ~145 readings at 10-minute sampling (24 h history); the backend
/// reports honest progress and the UI shows "Collecting telemetry history...".
class HiveAiReadiness {
  final int requiredReadings;
  final int currentReadings;
  final bool ready;

  const HiveAiReadiness({
    required this.requiredReadings,
    required this.currentReadings,
    required this.ready,
  });

  double get progress => requiredReadings <= 0
      ? 0.0
      : (currentReadings / requiredReadings).clamp(0.0, 1.0);

  factory HiveAiReadiness.fromJson(Map<String, dynamic> json) {
    return HiveAiReadiness(
      requiredReadings: (json['requiredReadings'] as num?)?.toInt() ?? 145,
      currentReadings: (json['currentReadings'] as num?)?.toInt() ?? 0,
      ready: json['ready'] as bool? ?? false,
    );
  }
}

/// Response of GET /api/hives/{hive_id}/telemetry/latest
class HiveSnapshot {
  final String hiveId;
  final String? hiveCode;
  final String? deviceId;
  final bool hasTelemetry;
  final bool hasAiAnalysis;
  final HiveTelemetrySample? telemetry;
  final HiveAiStatus? aiStatus;
  final HiveAiReadiness? aiReadiness;

  const HiveSnapshot({
    required this.hiveId,
    this.hiveCode,
    this.deviceId,
    required this.hasTelemetry,
    required this.hasAiAnalysis,
    this.telemetry,
    this.aiStatus,
    this.aiReadiness,
  });

  factory HiveSnapshot.fromJson(Map<String, dynamic> json) {
    return HiveSnapshot(
      hiveId: json['hiveId']?.toString() ?? '',
      hiveCode: json['hiveCode']?.toString(),
      deviceId: json['deviceId']?.toString(),
      hasTelemetry: json['hasTelemetry'] as bool? ?? false,
      hasAiAnalysis: json['hasAiAnalysis'] as bool? ?? false,
      telemetry: json['telemetry'] is Map<String, dynamic>
          ? HiveTelemetrySample.fromJson(json['telemetry'] as Map<String, dynamic>)
          : null,
      aiStatus: json['aiStatus'] is Map<String, dynamic>
          ? HiveAiStatus.fromJson(json['aiStatus'] as Map<String, dynamic>)
          : null,
      aiReadiness: json['aiReadiness'] is Map<String, dynamic>
          ? HiveAiReadiness.fromJson(json['aiReadiness'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Response of GET /api/hives/{hive_id}/status
class HiveAiStatusBundle {
  final String hiveId;
  final String? hiveCode;
  final String? deviceId;
  final bool hasAnalysis;
  final HiveAiStatus? aiStatus;
  final HiveAiReadiness? aiReadiness;

  const HiveAiStatusBundle({
    required this.hiveId,
    this.hiveCode,
    this.deviceId,
    required this.hasAnalysis,
    this.aiStatus,
    this.aiReadiness,
  });

  factory HiveAiStatusBundle.fromJson(Map<String, dynamic> json) {
    return HiveAiStatusBundle(
      hiveId: json['hiveId']?.toString() ?? '',
      hiveCode: json['hiveCode']?.toString(),
      deviceId: json['deviceId']?.toString(),
      hasAnalysis: json['hasAnalysis'] as bool? ?? false,
      aiStatus: json['aiStatus'] is Map<String, dynamic>
          ? HiveAiStatus.fromJson(json['aiStatus'] as Map<String, dynamic>)
          : null,
      aiReadiness: json['aiReadiness'] is Map<String, dynamic>
          ? HiveAiReadiness.fromJson(json['aiReadiness'] as Map<String, dynamic>)
          : null,
    );
  }
}
