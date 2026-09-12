import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';

/// Hive Data Model for HoneyChain
class Hive {
  final String id;
  final String? userId;
  final String name;
  final String hiveCode;
  final String apiaryLocation;
  final String hiveType;
  final DateTime dateAdded;
  final String queenStatus;

  // Hive Details
  final int totalFrames;
  final int broodFrames;
  final String colonyStrength;
  final int queenAgeMonths;
  final String beeBreed;

  // Production Information
  final double expectedProductionKg;
  final double previousYearProductionKg;
  final double currentYearProductionKg;
  final String honeyType;

  // Health & Inspection
  final DateTime lastInspectionDate;
  final String miteStatus;
  final String diseaseStatus;
  final bool feedingRequired;
  final String queenCondition;
  final String overallHealth;

  // Additional Notes
  final String notes;
  final DateTime updatedAt;

  String get location => apiaryLocation;

  const Hive({
    required this.id,
    this.userId,
    required this.name,
    required this.hiveCode,
    required this.apiaryLocation,
    required this.hiveType,
    required this.dateAdded,
    required this.queenStatus,
    required this.totalFrames,
    required this.broodFrames,
    required this.colonyStrength,
    required this.queenAgeMonths,
    required this.beeBreed,
    required this.expectedProductionKg,
    required this.previousYearProductionKg,
    required this.currentYearProductionKg,
    required this.honeyType,
    required this.lastInspectionDate,
    required this.miteStatus,
    required this.diseaseStatus,
    required this.feedingRequired,
    required this.queenCondition,
    required this.overallHealth,
    required this.notes,
    required this.updatedAt,
  });

  // Calculations & Getters

  /// Production difference in kg (current - previous)
  double get productionDifference =>
      currentYearProductionKg - previousYearProductionKg;

  /// Production percentage change relative to previous year
  double get productionChangePercentage {
    if (previousYearProductionKg <= 0) return 0.0;
    return ((currentYearProductionKg - previousYearProductionKg) /
            previousYearProductionKg) *
        100;
  }

  /// Remaining expected production in kg
  double get remainingExpectedProductionKg {
    final diff = expectedProductionKg - currentYearProductionKg;
    return diff > 0 ? diff : 0.0;
  }

  /// Occupied frame ratio string (e.g. "6 / 10")
  String get occupiedFrameRatio => '$broodFrames / $totalFrames';

  /// Occupied frame percentage
  double get occupiedFramePercentage {
    if (totalFrames <= 0) return 0.0;
    return (broodFrames / totalFrames) * 100;
  }

  /// Calculated next inspection date (7 days if attention/critical, 14 days if healthy)
  DateTime get nextInspectionDate {
    final intervalDays = isHealthy ? 14 : 7;
    return lastInspectionDate.add(Duration(days: intervalDays));
  }

  /// Whether hive is in healthy state
  bool get isHealthy => overallHealth.trim().toLowerCase() == 'healthy';

  /// Whether queen condition is optimal
  bool get isQueenHealthy =>
      queenCondition.trim().toLowerCase() == 'excellent' ||
      queenCondition.trim().toLowerCase() == 'good';

  /// Quick status indicator color
  Color get statusColor {
    switch (overallHealth.trim().toLowerCase()) {
      case 'healthy':
        return AppConstants.success;
      case 'needs attention':
        return AppConstants.warning;
      case 'critical':
        return AppConstants.error;
      default:
        return AppConstants.textMuted;
    }
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'userId': userId,
      'name': name,
      'hiveCode': hiveCode,
      'apiaryLocation': apiaryLocation,
      'hiveType': hiveType,
      'dateAdded': dateAdded.toIso8601String(),
      'queenStatus': queenStatus,
      'totalFrames': totalFrames,
      'broodFrames': broodFrames,
      'colonyStrength': colonyStrength,
      'queenAgeMonths': queenAgeMonths,
      'beeBreed': beeBreed,
      'expectedProductionKg': expectedProductionKg,
      'previousYearProductionKg': previousYearProductionKg,
      'currentYearProductionKg': currentYearProductionKg,
      'honeyType': honeyType,
      'lastInspectionDate': lastInspectionDate.toIso8601String(),
      'miteStatus': miteStatus,
      'diseaseStatus': diseaseStatus,
      'feedingRequired': feedingRequired,
      'queenCondition': queenCondition,
      'overallHealth': overallHealth,
      'notes': notes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Factory from JSON map
  factory Hive.fromJson(Map<String, dynamic> json) {
    return Hive(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      name: json['name'] as String? ?? 'Unnamed Hive',
      hiveCode: json['hiveCode'] as String? ?? '',
      apiaryLocation: json['apiaryLocation'] as String? ?? 'Main Apiary',
      hiveType: json['hiveType'] as String? ?? 'Langstroth',
      dateAdded: DateTime.tryParse(json['dateAdded'] as String? ?? '') ??
          DateTime.now(),
      queenStatus: json['queenStatus'] as String? ?? 'Mated',
      totalFrames: (json['totalFrames'] as num?)?.toInt() ?? 10,
      broodFrames: (json['broodFrames'] as num?)?.toInt() ?? 0,
      colonyStrength: json['colonyStrength'] as String? ?? 'Strong',
      queenAgeMonths: (json['queenAgeMonths'] as num?)?.toInt() ?? 0,
      beeBreed: json['beeBreed'] as String? ?? 'Italian',
      expectedProductionKg:
          (json['expectedProductionKg'] as num?)?.toDouble() ?? 0.0,
      previousYearProductionKg:
          (json['previousYearProductionKg'] as num?)?.toDouble() ?? 0.0,
      currentYearProductionKg:
          (json['currentYearProductionKg'] as num?)?.toDouble() ?? 0.0,
      honeyType: json['honeyType'] as String? ?? 'Wildflower',
      lastInspectionDate:
          DateTime.tryParse(json['lastInspectionDate'] as String? ?? '') ??
              DateTime.now(),
      miteStatus: json['miteStatus'] as String? ?? 'None',
      diseaseStatus: json['diseaseStatus'] as String? ?? 'None',
      feedingRequired: json['feedingRequired'] as bool? ?? false,
      queenCondition: json['queenCondition'] as String? ?? 'Good',
      overallHealth: json['overallHealth'] as String? ?? 'Healthy',
      notes: json['notes'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Copy with modifications
  Hive copyWith({
    String? id,
    String? userId,
    String? name,
    String? hiveCode,
    String? apiaryLocation,
    String? hiveType,
    DateTime? dateAdded,
    String? queenStatus,
    int? totalFrames,
    int? broodFrames,
    String? colonyStrength,
    int? queenAgeMonths,
    String? beeBreed,
    double? expectedProductionKg,
    double? previousYearProductionKg,
    double? currentYearProductionKg,
    String? honeyType,
    DateTime? lastInspectionDate,
    String? miteStatus,
    String? diseaseStatus,
    bool? feedingRequired,
    String? queenCondition,
    String? overallHealth,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Hive(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      hiveCode: hiveCode ?? this.hiveCode,
      apiaryLocation: apiaryLocation ?? this.apiaryLocation,
      hiveType: hiveType ?? this.hiveType,
      dateAdded: dateAdded ?? this.dateAdded,
      queenStatus: queenStatus ?? this.queenStatus,
      totalFrames: totalFrames ?? this.totalFrames,
      broodFrames: broodFrames ?? this.broodFrames,
      colonyStrength: colonyStrength ?? this.colonyStrength,
      queenAgeMonths: queenAgeMonths ?? this.queenAgeMonths,
      beeBreed: beeBreed ?? this.beeBreed,
      expectedProductionKg: expectedProductionKg ?? this.expectedProductionKg,
      previousYearProductionKg:
          previousYearProductionKg ?? this.previousYearProductionKg,
      currentYearProductionKg:
          currentYearProductionKg ?? this.currentYearProductionKg,
      honeyType: honeyType ?? this.honeyType,
      lastInspectionDate: lastInspectionDate ?? this.lastInspectionDate,
      miteStatus: miteStatus ?? this.miteStatus,
      diseaseStatus: diseaseStatus ?? this.diseaseStatus,
      feedingRequired: feedingRequired ?? this.feedingRequired,
      queenCondition: queenCondition ?? this.queenCondition,
      overallHealth: overallHealth ?? this.overallHealth,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

