import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/workflow_request.dart';

class WorkflowController extends ChangeNotifier {
  List<WorkflowRequest> _requests = [];
  bool isLoading = false;
  String? errorMessage;

  final String apiUrl = 'http://127.0.0.1:3000/api';

  List<WorkflowRequest> get allRequests => List.unmodifiable(_requests);
  List<WorkflowRequest> get harvesterRequests => _requests.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<WorkflowRequest> get collectionRequests => _requests.where((r) => r.status == RequestStatus.pending || r.status == RequestStatus.accepted).toList();
  List<WorkflowRequest> get labRequests => _requests.where((r) => r.status == RequestStatus.awaitingTest || r.status == RequestStatus.testing || r.status == RequestStatus.labApproved).toList();
  List<WorkflowRequest> get packagingRequests => _requests.where((r) => r.status == RequestStatus.readyForPackaging || r.status == RequestStatus.packagingApproved || r.status == RequestStatus.qrGenerated || r.status == RequestStatus.completed).toList();

  Future<void> fetchBatches() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$apiUrl/batches'));
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
      final response = await http.post(
        Uri.parse('$apiUrl/harvests'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'harvesterId': harvesterName,
          'hiveId': 'HIVE-1', // Defaulted for this integration
          'quantity': estimatedQuantityKg,
          'location': location,
          'notes': notes,
        }),
      );
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Create Harvest Error: $e");
    }
  }

  Future<void> processBatch(String batchId, String processorId, double qtyReceived, double qtyAfter, String method, String notes) async {
    try {
      final response = await http.post(
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
      );
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Process Batch Error: $e");
    }
  }

  Future<void> submitLabReport(String batchId, String labId, String results, double score, String notes) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/lab-reports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batchId': batchId,
          'labId': labId,
          'testResults': results,
          'qualityScore': score,
          'notes': notes,
        }),
      );
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Lab Report Error: $e");
    }
  }

  Future<void> completePackaging(String batchId, String packagerId, double qty, int numPackages, String notes) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/packaging'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'batchId': batchId,
          'packagerId': packagerId,
          'finalQuantity': qty,
          'numberOfPackages': numPackages,
          'notes': notes,
        }),
      );
      if (response.statusCode == 200) {
        await fetchBatches();
      }
    } catch (e) {
      debugPrint("Packaging Error: $e");
    }
  }

  // Placeholder methods for UI compatibility
  void acceptRequest(String id) {}
  void denyRequest(String id, String reason) {}
  void updateStatus(String id, RequestStatus newStatus) {}
  void markLabRejected(String id, String reason) {}
    // Restore aliases for UI compatibility
  List<WorkflowRequest> get pendingCollectionRequests => _requests.where((r) => r.status == RequestStatus.pending).toList();
  List<WorkflowRequest> get collectionHistory => _requests.where((r) => r.status != RequestStatus.pending && r.status != RequestStatus.accepted).toList();
  List<WorkflowRequest> get labPendingRequests => _requests.where((r) => r.status == RequestStatus.awaitingTest).toList();
  List<WorkflowRequest> get labHistory => _requests.where((r) => r.status == RequestStatus.labApproved || r.status == RequestStatus.labRejected).toList();
  List<WorkflowRequest> get packagingPendingRequests => _requests.where((r) => r.status == RequestStatus.readyForPackaging).toList();
  List<WorkflowRequest> get packagingHistory => _requests.where((r) => r.status == RequestStatus.packagingApproved || r.status == RequestStatus.qrGenerated || r.status == RequestStatus.completed).toList();

  void generateQr(String id) {
    updateStatus(id, RequestStatus.qrGenerated);
  }
  void allowPackaging(String id) {
    updateStatus(id, RequestStatus.packagingApproved);
  }
}

