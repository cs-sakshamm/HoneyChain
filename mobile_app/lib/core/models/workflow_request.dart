// Updated WorkflowRequest Model
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

  // Blockchain Provenance
  String? txHash;
  String? blockNumber;
  String? dataHash;

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
    this.txHash,
    this.blockNumber,
    this.dataHash,
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

  factory WorkflowRequest.fromJson(Map<String, dynamic> json) {
    // Map backend response Batch to WorkflowRequest for UI compatibility
    return WorkflowRequest(
      id: json['harvest']?.['id'] ?? 'N/A',
      batchId: json['id'] ?? 'UNKNOWN',
      harvesterName: json['harvest']?.['harvesterId'] ?? 'Unknown',
      collectionType: 'Standard Collection',
      location: json['harvest']?.['location'] ?? 'Unknown',
      description: 'Harvest from Hive ${json['harvest']?.['hiveId']}',
      estimatedQuantityKg: (json['harvest']?.['quantity'] ?? 0).toDouble(),
      notes: json['harvest']?.['notes'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: _parseStatus(json['status']),
      txHash: json['provenanceEvents']?.length > 0 ? json['provenanceEvents'].last['txHash'] : null,
      dataHash: json['provenanceEvents']?.length > 0 ? json['provenanceEvents'].last['dataHash'] : null,
    );
  }
}

enum RequestStatus {
  pending, accepted, denied, processing, awaitingTest, testing, labApproved, labRejected, readyForPackaging, packagingApproved, qrGenerated, completed,
}

RequestStatus _parseStatus(String? status) {
  switch (status) {
    case 'HARVESTED': return RequestStatus.pending;
    case 'PROCESSING_COMPLETED': return RequestStatus.awaitingTest;
    case 'LAB_APPROVED': return RequestStatus.readyForPackaging;
    case 'PACKAGED': return RequestStatus.completed;
    default: return RequestStatus.pending;
  }
}

extension RequestStatusLabel on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending: return 'Pending';
      case RequestStatus.accepted: return 'Accepted';
      case RequestStatus.denied: return 'Denied';
      case RequestStatus.processing: return 'Processing';
      case RequestStatus.awaitingTest: return 'Awaiting Test';
      case RequestStatus.testing: return 'Testing';
      case RequestStatus.labApproved: return 'Lab Approved';
      case RequestStatus.labRejected: return 'Lab Rejected';
      case RequestStatus.readyForPackaging: return 'Ready for Packaging';
      case RequestStatus.packagingApproved: return 'Packaging Approved';
      case RequestStatus.qrGenerated: return 'QR Generated';
      case RequestStatus.completed: return 'Completed';
    }
  }
}
