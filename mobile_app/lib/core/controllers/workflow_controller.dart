import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/workflow_request.dart';

class WorkflowController extends ChangeNotifier {
  List<WorkflowRequest> _requests = [];
  bool isLoading = false;
  String? errorMessage;

  final String apiUrl;
  final http.Client _client;

  WorkflowController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        apiUrl = baseUrl ?? _resolveApiUrl() {
    fetchBatches();
  }

  static String _resolveApiUrl() {
    if (kIsWeb) {
      return '${AppConstants.backendBaseUrl}/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {}
    return '${AppConstants.backendBaseUrl}/api';
  }

  List<WorkflowRequest> get allRequests => List.unmodifiable(_requests);
  List<WorkflowRequest> get harvesterRequests =>
      _requests.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<WorkflowRequest> get collectionRequests => _requests
      .where((r) =>
          r.status == RequestStatus.pending ||
          r.status == RequestStatus.accepted)
      .toList();
  List<WorkflowRequest> get labRequests => _requests
      .where((r) =>
          r.status == RequestStatus.awaitingTest ||
          r.status == RequestStatus.testing ||
          r.status == RequestStatus.labApproved)
      .toList();
  List<WorkflowRequest> get packagingRequests => _requests
      .where((r) =>
          r.status == RequestStatus.readyForPackaging ||
          r.status == RequestStatus.packagingApproved ||
          r.status == RequestStatus.qrGenerated ||
          r.status == RequestStatus.completed)
      .toList();

  Future<void> fetchBatches() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _client.get(Uri.parse('$apiUrl/batches')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _requests = data.map((json) => WorkflowRequest.fromJson(json)).toList();
      } else {
        errorMessage = 'Failed to load batches: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Network error: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRequest({
    required String harvesterName,
    required String collectionType,
    required String location,
    required String description,
    required double estimatedQuantityKg,
    String notes = '',
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiUrl/harvests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'harvesterId': harvesterName,
          'hiveId': 'hive_sample_1',
          'quantity': estimatedQuantityKg,
          'location': location,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Create Harvest Error: $e");
    }
  }

  Future<void> processBatch(String batchId, String processorId, double qtyReceived,
      double qtyAfter, String method, String notes) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiUrl/processing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batchId': batchId,
          'processorId': processorId,
          'quantityReceived': qtyReceived,
          'quantityAfter': qtyAfter,
          'method': method,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Process Batch Error: $e");
    }
  }

  Future<void> submitLabReport(String batchId, String labId, String results,
      double score, String notes) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiUrl/lab-reports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batchId': batchId,
          'labId': labId,
          'testResults': results,
          'qualityScore': score,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Lab Report Error: $e");
    }
  }

  Future<void> completePackaging(String batchId, String packagerId, double qty,
      int numPackages, String notes) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiUrl/packaging'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batchId': batchId,
          'packagerId': packagerId,
          'finalQuantity': qty,
          'numberOfPackages': numPackages,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Packaging Error: $e");
    }
  }

  void acceptRequest(String id) {
    updateStatus(id, RequestStatus.accepted);
  }

  void denyRequest(String id, String reason) {
    updateStatus(id, RequestStatus.denied);
  }

  void updateStatus(String id, RequestStatus newStatus) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final req = _requests[index];
      _requests[index] = WorkflowRequest(
        id: req.id,
        batchId: req.batchId,
        harvesterName: req.harvesterName,
        collectionType: req.collectionType,
        location: req.location,
        description: req.description,
        estimatedQuantityKg: req.estimatedQuantityKg,
        notes: req.notes,
        createdAt: req.createdAt,
        status: newStatus,
        dataHash: req.dataHash,
        txHash: req.txHash,
        blockNumber: req.blockNumber,
        labSampleId: req.labSampleId,
        moistureContent: req.moistureContent,
        purityGrade: req.purityGrade,
        contaminantsFound: req.contaminantsFound,
        qualityScore: req.qualityScore,
        labNotes: req.labNotes,
        labReportDate: req.labReportDate,
        packagingApprovedDate: req.packagingApprovedDate,
        qrGenerated: req.qrGenerated,
        denialReason: req.denialReason,
      );
      notifyListeners();
    }
  }

  void markLabRejected(String id, String reason) {
    updateStatus(id, RequestStatus.labRejected);
  }

  List<WorkflowRequest> get pendingCollectionRequests =>
      _requests.where((r) => r.status == RequestStatus.pending).toList();
  List<WorkflowRequest> get collectionHistory => _requests
      .where((r) =>
          r.status != RequestStatus.pending &&
          r.status != RequestStatus.accepted)
      .toList();
  List<WorkflowRequest> get labPendingRequests =>
      _requests.where((r) => r.status == RequestStatus.awaitingTest).toList();
  List<WorkflowRequest> get labHistory => _requests
      .where((r) =>
          r.status == RequestStatus.labApproved ||
          r.status == RequestStatus.labRejected)
      .toList();
  List<WorkflowRequest> get packagingPendingRequests =>
      _requests.where((r) => r.status == RequestStatus.readyForPackaging).toList();
  List<WorkflowRequest> get packagingHistory => _requests
      .where((r) =>
          r.status == RequestStatus.packagingApproved ||
          r.status == RequestStatus.qrGenerated ||
          r.status == RequestStatus.completed)
      .toList();

  void generateQr(String id) {
    updateStatus(id, RequestStatus.qrGenerated);
  }

  void allowPackaging(String id) {
    updateStatus(id, RequestStatus.packagingApproved);
  }
}
