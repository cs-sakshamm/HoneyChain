// Comprehensive WorkflowRequest Model for End-to-End Request Chain
class WorkflowRequest {
  final String id;
  final String requestId;
  final String batchId;
  final String harvesterName;
  final String fromRole;
  final String toRole;
  final String requestType;
  final String collectionType;
  final String location;
  final String description;
  final double estimatedQuantityKg;
  final String notes;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? rejectedAt;
  final String? previousRequestId;
  RequestStatus status;

  // Blockchain Provenance
  String? txHash;
  String? blockNumber;
  String? dataHash;
  String? blockchainStatus; // 'CONFIRMED', 'PENDING', 'FAILED'

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
  int? numberOfPackages;
  double? finalQuantity;
  String? packageSize;
  String? qrCodeUrl;
  bool qrGenerated;
  String? denialReason;

  // Audit History
  List<RequestHistoryItem> history;

  WorkflowRequest({
    required this.id,
    String? requestId,
    required this.batchId,
    required this.harvesterName,
    this.fromRole = 'HARVESTER',
    this.toRole = 'COLLECTOR_PROCESSOR',
    this.requestType = 'HARVEST_TO_COLLECTION',
    this.collectionType = 'Standard Collection',
    this.location = 'Apiary Site',
    this.description = '',
    required this.estimatedQuantityKg,
    this.notes = '',
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.rejectedAt,
    this.previousRequestId,
    this.status = RequestStatus.pending,
    this.txHash,
    this.blockNumber,
    this.dataHash,
    this.blockchainStatus = 'CONFIRMED',
    this.labSampleId,
    this.moistureContent,
    this.purityGrade,
    this.contaminantsFound,
    this.qualityScore,
    this.labNotes,
    this.labReportDate,
    this.packagingApprovedDate,
    this.numberOfPackages,
    this.finalQuantity,
    this.packageSize,
    this.qrCodeUrl,
    this.qrGenerated = false,
    this.denialReason,
    this.history = const [],
  }) : requestId = requestId ?? (id.length > 8 ? id.substring(0, 8) : id);

  WorkflowRequest copyWith({
    String? id,
    String? requestId,
    String? batchId,
    String? harvesterName,
    String? fromRole,
    String? toRole,
    String? requestType,
    String? collectionType,
    String? location,
    String? description,
    double? estimatedQuantityKg,
    String? notes,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? rejectedAt,
    String? previousRequestId,
    RequestStatus? status,
    String? txHash,
    String? blockNumber,
    String? dataHash,
    String? blockchainStatus,
    String? labSampleId,
    double? moistureContent,
    double? purityGrade,
    String? contaminantsFound,
    double? qualityScore,
    String? labNotes,
    DateTime? labReportDate,
    DateTime? packagingApprovedDate,
    int? numberOfPackages,
    double? finalQuantity,
    String? packageSize,
    String? qrCodeUrl,
    bool? qrGenerated,
    String? denialReason,
    List<RequestHistoryItem>? history,
  }) {
    return WorkflowRequest(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      batchId: batchId ?? this.batchId,
      harvesterName: harvesterName ?? this.harvesterName,
      fromRole: fromRole ?? this.fromRole,
      toRole: toRole ?? this.toRole,
      requestType: requestType ?? this.requestType,
      collectionType: collectionType ?? this.collectionType,
      location: location ?? this.location,
      description: description ?? this.description,
      estimatedQuantityKg: estimatedQuantityKg ?? this.estimatedQuantityKg,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      previousRequestId: previousRequestId ?? this.previousRequestId,
      status: status ?? this.status,
      txHash: txHash ?? this.txHash,
      blockNumber: blockNumber ?? this.blockNumber,
      dataHash: dataHash ?? this.dataHash,
      blockchainStatus: blockchainStatus ?? this.blockchainStatus,
      labSampleId: labSampleId ?? this.labSampleId,
      moistureContent: moistureContent ?? this.moistureContent,
      purityGrade: purityGrade ?? this.purityGrade,
      contaminantsFound: contaminantsFound ?? this.contaminantsFound,
      qualityScore: qualityScore ?? this.qualityScore,
      labNotes: labNotes ?? this.labNotes,
      labReportDate: labReportDate ?? this.labReportDate,
      packagingApprovedDate: packagingApprovedDate ?? this.packagingApprovedDate,
      numberOfPackages: numberOfPackages ?? this.numberOfPackages,
      finalQuantity: finalQuantity ?? this.finalQuantity,
      packageSize: packageSize ?? this.packageSize,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      qrGenerated: qrGenerated ?? this.qrGenerated,
      denialReason: denialReason ?? this.denialReason,
      history: history ?? this.history,
    );
  }

  factory WorkflowRequest.fromJson(Map<String, dynamic> json) {
    // Determine if parsing from /api/requests or /api/batches
    final isDirectRequest = json.containsKey('requestType') || json.containsKey('requestId');

    if (isDirectRequest) {
      final batchObj = json['batch'] is Map<String, dynamic> ? json['batch'] : null;
      final harvestObj = batchObj != null && batchObj['harvest'] is Map<String, dynamic> ? batchObj['harvest'] : null;
      final harvesterObj = harvestObj != null && harvestObj['harvester'] is Map<String, dynamic> ? harvestObj['harvester'] : null;
      final fromUserObj = json['fromUser'] is Map<String, dynamic> ? json['fromUser'] : null;
      final labReportObj = json['labReport'] is Map<String, dynamic> ? json['labReport'] : null;
      final pkgRecordObj = json['packagingRecord'] is Map<String, dynamic> ? json['packagingRecord'] : null;

      final historyList = json['history'] is List
          ? (json['history'] as List).map((h) => RequestHistoryItem.fromJson(h)).toList()
          : <RequestHistoryItem>[];

      final provList = json['provenanceEvents'] is List ? json['provenanceEvents'] as List : [];
      final latestProv = provList.isNotEmpty ? provList.first : null;

      return WorkflowRequest(
        id: json['id'] ?? '',
        requestId: json['requestId'] ?? json['id'] ?? '',
        batchId: json['batchId'] ?? (batchObj != null ? batchObj['id'] : 'UNKNOWN'),
        harvesterName: fromUserObj?['name'] ?? harvesterObj?['name'] ?? 'Harvester',
        fromRole: json['fromRole'] ?? 'HARVESTER',
        toRole: json['toRole'] ?? 'COLLECTOR_PROCESSOR',
        requestType: json['requestType'] ?? 'HARVEST_TO_COLLECTION',
        collectionType: 'Standard Collection',
        location: harvestObj?['location'] ?? 'Apiary Site',
        description: 'Batch ${json['batchId'] ?? ''}',
        estimatedQuantityKg: (json['quantity'] ?? harvestObj?['quantity'] ?? 0).toDouble(),
        notes: json['notes'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        acceptedAt: json['acceptedAt'] != null ? DateTime.tryParse(json['acceptedAt']) : null,
        completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
        rejectedAt: json['rejectedAt'] != null ? DateTime.tryParse(json['rejectedAt']) : null,
        previousRequestId: json['previousRequestId'],
        status: _parseStatus(json['status']),
        txHash: latestProv?['txHash'] ?? json['txHash'],
        blockNumber: latestProv?['blockNumber']?.toString() ?? json['blockNumber']?.toString(),
        dataHash: latestProv?['dataHash'] ?? json['dataHash'],
        blockchainStatus: latestProv?['status'] ?? 'CONFIRMED',
        labSampleId: labReportObj?['id'],
        moistureContent: labReportObj?['moistureContent'] != null ? (labReportObj!['moistureContent'] as num).toDouble() : null,
        purityGrade: labReportObj?['purityGrade'] != null ? double.tryParse(labReportObj!['purityGrade'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) : null,
        contaminantsFound: labReportObj?['contaminantsFound'],
        qualityScore: labReportObj?['qualityScore'] != null ? (labReportObj!['qualityScore'] as num).toDouble() : null,
        labNotes: labReportObj?['notes'],
        labReportDate: labReportObj?['createdAt'] != null ? DateTime.tryParse(labReportObj!['createdAt']) : null,
        packagingApprovedDate: pkgRecordObj?['createdAt'] != null ? DateTime.tryParse(pkgRecordObj!['createdAt']) : null,
        numberOfPackages: pkgRecordObj?['numberOfPackages'],
        finalQuantity: pkgRecordObj?['finalQuantity'] != null ? (pkgRecordObj!['finalQuantity'] as num).toDouble() : null,
        packageSize: pkgRecordObj?['packageSize'],
        qrCodeUrl: pkgRecordObj?['qrCodeUrl'],
        qrGenerated: pkgRecordObj != null,
        history: historyList,
      );
    }

    // Fallback: Map batch JSON to WorkflowRequest
    final harvest = json['harvest'] ?? {};
    final harvester = harvest['harvester'] ?? {};
    final provEvents = json['provenanceEvents'] as List? ?? [];
    final latestEvent = provEvents.isNotEmpty ? provEvents.last : null;
    final labReports = json['labReports'] as List? ?? [];
    final latestLab = labReports.isNotEmpty ? labReports.first : null;
    final pkgRecords = json['packagingRecords'] as List? ?? [];
    final latestPkg = pkgRecords.isNotEmpty ? pkgRecords.first : null;

    return WorkflowRequest(
      id: harvest['id'] ?? json['id'] ?? 'N/A',
      requestId: json['id'] ?? 'UNKNOWN',
      batchId: json['id'] ?? 'UNKNOWN',
      harvesterName: harvester['name'] ?? harvest['harvesterId'] ?? 'Unknown Harvester',
      fromRole: 'HARVESTER',
      toRole: 'COLLECTOR_PROCESSOR',
      requestType: 'HARVEST_TO_COLLECTION',
      collectionType: 'Standard Collection',
      location: harvest['location'] ?? 'Apiary Site',
      description: 'Harvest from Hive ${harvest['hiveId'] ?? ''}',
      estimatedQuantityKg: ((harvest['quantity'] ?? 0) as num).toDouble(),
      notes: harvest['notes'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status']),
      txHash: latestEvent?['txHash'],
      blockNumber: latestEvent?['blockNumber']?.toString(),
      dataHash: latestEvent?['dataHash'],
      blockchainStatus: latestEvent?['status'] ?? 'CONFIRMED',
      qualityScore: latestLab?['qualityScore'] != null ? (latestLab!['qualityScore'] as num).toDouble() : null,
      moistureContent: latestLab?['moistureContent'] != null ? (latestLab!['moistureContent'] as num).toDouble() : null,
      qrGenerated: latestPkg != null,
      qrCodeUrl: latestPkg?['qrCodeUrl'],
    );
  }
}

class RequestHistoryItem {
  final String id;
  final String action;
  final String? fromStatus;
  final String toStatus;
  final String actorName;
  final String actorRole;
  final String? notes;
  final DateTime createdAt;

  RequestHistoryItem({
    required this.id,
    required this.action,
    this.fromStatus,
    required this.toStatus,
    required this.actorName,
    required this.actorRole,
    this.notes,
    required this.createdAt,
  });

  factory RequestHistoryItem.fromJson(Map<String, dynamic> json) {
    final actorObj = json['actor'] is Map<String, dynamic> ? json['actor'] : null;
    return RequestHistoryItem(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      fromStatus: json['fromStatus'],
      toStatus: json['toStatus'] ?? '',
      actorName: actorObj?['name'] ?? json['actorId'] ?? 'Actor',
      actorRole: json['actorRole'] ?? 'OFFICER',
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
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

RequestStatus _parseStatus(String? status) {
  switch (status?.toUpperCase()) {
    case 'PENDING':
    case 'PENDING_COLLECTION':
    case 'REQUESTED':
    case 'HARVESTED':
      return RequestStatus.pending;
    case 'ACCEPTED':
    case 'COLLECTION_ACCEPTED':
      return RequestStatus.accepted;
    case 'REJECTED':
    case 'COLLECTION_REJECTED':
    case 'DENIED':
      return RequestStatus.denied;
    case 'PROCESSING':
    case 'PROCESSING_IN_PROGRESS':
      return RequestStatus.processing;
    case 'PENDING_LAB':
    case 'PROCESSING_COMPLETED':
    case 'AWAITING_TEST':
    case 'SENT_TO_LAB': // dispatch completed: harvest left the collector's Accepted queue
      return RequestStatus.awaitingTest;
    case 'IN_PROGRESS':
    case 'TESTING':
    case 'LAB_ACCEPTED':
      return RequestStatus.testing;
    case 'VERIFIED':
    case 'LAB_VERIFIED':
    case 'LAB_APPROVED':
    case 'APPROVED':
      return RequestStatus.labApproved;
    case 'LAB_REJECTED':
      return RequestStatus.labRejected;
    case 'PENDING_PACKAGING':
    case 'READY_FOR_PACKAGING':
      return RequestStatus.readyForPackaging;
    case 'PACKAGING_ACCEPTED':
    case 'PACKAGING_APPROVED':
      return RequestStatus.packagingApproved;
    case 'QR_GENERATED':
      return RequestStatus.qrGenerated;
    case 'COMPLETED':
    case 'PACKAGED':
      return RequestStatus.completed;
    default:
      return RequestStatus.pending;
  }
}

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
        return 'In Testing';
      case RequestStatus.labApproved:
        return 'Lab Verified';
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


