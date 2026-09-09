/// Workflow Request Data Model for HoneyChain Supply Chain
class WorkflowRequest {
  final String id;
  final String batchId;
  final String harvesterName;
  final String collectionType;
  final String location;
  final String description;
  final double estimatedQuantityKg;
  final String notes;
  final DateTime createdAt;
  RequestStatus status;

  // Lab report fields
  String? labSampleId;
  double? moistureContent;
  double? purityGrade;
  String? contaminantsFound;
  double? qualityScore;
  String? labNotes;
  DateTime? labReportDate;

  // Packaging fields
  DateTime? packagingApprovedDate;
  bool qrGenerated;
  String? denialReason;

  WorkflowRequest({
    required this.id,
    required this.batchId,
    required this.harvesterName,
    required this.collectionType,
    required this.location,
    required this.description,
    required this.estimatedQuantityKg,
    this.notes = '',
    required this.createdAt,
    this.status = RequestStatus.pending,
    this.labSampleId,
    this.moistureContent,
    this.purityGrade,
    this.contaminantsFound,
    this.qualityScore,
    this.labNotes,
    this.labReportDate,
    this.packagingApprovedDate,
    this.qrGenerated = false,
    this.denialReason,
  });
}

enum RequestStatus {
  pending,
  accepted,
  denied,
  processing,
  awaitingTest,
  testing,
  labApproved,
  labRejected,
  readyForPackaging,
  packagingApproved,
  qrGenerated,
  completed,
}

/// Human-readable label for each status
extension RequestStatusLabel on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.denied:
        return 'Denied';
      case RequestStatus.processing:
        return 'Processing';
      case RequestStatus.awaitingTest:
        return 'Awaiting Test';
      case RequestStatus.testing:
        return 'Testing';
      case RequestStatus.labApproved:
        return 'Lab Approved';
      case RequestStatus.labRejected:
        return 'Lab Rejected';
      case RequestStatus.readyForPackaging:
        return 'Ready for Packaging';
      case RequestStatus.packagingApproved:
        return 'Packaging Approved';
      case RequestStatus.qrGenerated:
        return 'QR Generated';
      case RequestStatus.completed:
        return 'Completed';
    }
  }
}
