import 'package:flutter/material.dart';

import '../models/workflow_request.dart';

/// Shared workflow state managing all supply chain requests across roles.
/// Each action method immediately mutates state — no confirmation steps.
class WorkflowController extends ChangeNotifier {
  final List<WorkflowRequest> _requests = [];
  int _requestCounter = 0;

  List<WorkflowRequest> get allRequests => List.unmodifiable(_requests);

  // ── Harvester ──────────────────────────────────────────────────────────

  /// Requests created by the current harvester session
  List<WorkflowRequest> get harvesterRequests =>
      _requests.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Immediately creates a new collection request (no confirmation)
  void createRequest({
    required String harvesterName,
    required String collectionType,
    required String location,
    required String description,
    required double estimatedQuantityKg,
    String notes = '',
  }) {
    _requestCounter++;
    final now = DateTime.now();
    final batchId = 'HC-${now.year}-${_requestCounter.toString().padLeft(3, '0')}';
    final labSampleId = 'LAB-${now.year}-${_requestCounter.toString().padLeft(3, '0')}';

    _requests.add(WorkflowRequest(
      id: 'REQ-${now.millisecondsSinceEpoch}',
      batchId: batchId,
      harvesterName: harvesterName,
      collectionType: collectionType,
      location: location,
      description: description,
      estimatedQuantityKg: estimatedQuantityKg,
      notes: notes,
      createdAt: now,
      labSampleId: labSampleId,
    ));
    notifyListeners();
  }

  // ── Collection & Processing ────────────────────────────────────────────

  /// Pending requests for Collection & Processing role
  List<WorkflowRequest> get pendingCollectionRequests =>
      _requests.where((r) => r.status == RequestStatus.pending).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Processed requests (accepted/denied) for Collection history
  List<WorkflowRequest> get collectionHistory =>
      _requests
          .where((r) =>
              r.status != RequestStatus.pending)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Immediately accepts a request and forwards to lab testing
  void acceptRequest(String requestId) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.status = RequestStatus.accepted;
    // Auto-advance to awaiting test
    req.status = RequestStatus.awaitingTest;
    notifyListeners();
  }

  /// Immediately denies a request
  void denyRequest(String requestId, {String? reason}) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.status = RequestStatus.denied;
    req.denialReason = reason;
    notifyListeners();
  }

  // ── Lab Testing ────────────────────────────────────────────────────────

  /// Requests awaiting lab testing
  List<WorkflowRequest> get labPendingRequests =>
      _requests
          .where((r) =>
              r.status == RequestStatus.awaitingTest ||
              r.status == RequestStatus.testing)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Lab history (reports submitted)
  List<WorkflowRequest> get labHistory =>
      _requests
          .where((r) =>
              r.status == RequestStatus.labApproved ||
              r.status == RequestStatus.labRejected ||
              r.status == RequestStatus.readyForPackaging ||
              r.status == RequestStatus.packagingApproved ||
              r.status == RequestStatus.qrGenerated ||
              r.status == RequestStatus.completed)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Immediately submits a lab report (no confirmation dialog)
  void submitLabReport({
    required String requestId,
    required double moistureContent,
    required double purityGrade,
    required String contaminantsFound,
    required double qualityScore,
    String labNotes = '',
  }) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.moistureContent = moistureContent;
    req.purityGrade = purityGrade;
    req.contaminantsFound = contaminantsFound;
    req.qualityScore = qualityScore;
    req.labNotes = labNotes;
    req.labReportDate = DateTime.now();
    req.status = RequestStatus.labApproved;
    notifyListeners();
  }

  /// Reject a lab sample
  void rejectLabSample(String requestId, {String? reason}) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.status = RequestStatus.labRejected;
    req.labNotes = reason ?? '';
    req.labReportDate = DateTime.now();
    notifyListeners();
  }

  // ── Packaging ──────────────────────────────────────────────────────────

  /// Requests ready for packaging
  List<WorkflowRequest> get packagingPendingRequests =>
      _requests
          .where((r) => r.status == RequestStatus.labApproved)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Packaging history
  List<WorkflowRequest> get packagingHistory =>
      _requests
          .where((r) =>
              r.status == RequestStatus.packagingApproved ||
              r.status == RequestStatus.qrGenerated ||
              r.status == RequestStatus.completed)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Allow packaging for a batch
  void allowPackaging(String requestId) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.status = RequestStatus.packagingApproved;
    req.packagingApprovedDate = DateTime.now();
    notifyListeners();
  }

  /// Generate QR code for a batch
  void generateQr(String requestId) {
    final req = _requests.firstWhere((r) => r.id == requestId);
    req.status = RequestStatus.qrGenerated;
    req.qrGenerated = true;
    notifyListeners();
  }
}
