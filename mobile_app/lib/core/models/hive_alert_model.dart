class HiveAlertModel {
  final String id;
  final String hiveId;
  final String hiveCode;
  final String parameter;
  final String previousValue;
  final String currentValue;
  final String changeValue;
  final String unit;
  final String severity; // CRITICAL, WARNING
  final String message;
  final String status; // ACTIVE, ACKNOWLEDGED
  final DateTime detectedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  const HiveAlertModel({
    required this.id,
    required this.hiveId,
    required this.hiveCode,
    required this.parameter,
    required this.previousValue,
    required this.currentValue,
    required this.changeValue,
    required this.unit,
    this.severity = 'CRITICAL',
    required this.message,
    this.status = 'ACTIVE',
    required this.detectedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory HiveAlertModel.fromJson(Map<String, dynamic> json) {
    return HiveAlertModel(
      id: json['id']?.toString() ?? '',
      hiveId: json['hiveId']?.toString() ?? '',
      hiveCode: json['hiveCode']?.toString() ?? 'HIVE-001',
      parameter: json['parameter']?.toString() ?? 'Temperature',
      previousValue: json['previousValue']?.toString() ?? '',
      currentValue: json['currentValue']?.toString() ?? '',
      changeValue: json['changeValue']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'CRITICAL',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      acknowledgedBy: json['acknowledgedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hiveId': hiveId,
      'hiveCode': hiveCode,
      'parameter': parameter,
      'previousValue': previousValue,
      'currentValue': currentValue,
      'changeValue': changeValue,
      'unit': unit,
      'severity': severity,
      'message': message,
      'status': status,
      'detectedAt': detectedAt.toIso8601String(),
      'acknowledgedAt': acknowledgedAt?.toIso8601String(),
      'acknowledgedBy': acknowledgedBy,
    };
  }
}
