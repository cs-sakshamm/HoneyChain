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
  String? lastSuccessMessage;

  final String apiUrl;
  final http.Client _client;

  WorkflowController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        apiUrl = baseUrl ?? _resolveApiUrl() {
    fetchAllData();
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

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  List<WorkflowRequest> get allRequests => List.unmodifiable(_requests);

  // ── Role Specific Getters ──
  List<WorkflowRequest> get harvesterRequests =>
      _requests.where((r) => r.fromRole == 'HARVESTER' || r.requestType == 'HARVEST_TO_COLLECTION').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get pendingCollectionRequests => _requests
      .where((r) =>
          r.toRole == 'COLLECTOR_PROCESSOR' &&
          r.requestType == 'HARVEST_TO_COLLECTION' &&
          r.status == RequestStatus.pending)
      .toList();

  List<WorkflowRequest> get acceptedCollectionRequests => _requests
      .where((r) =>
          r.toRole == 'COLLECTOR_PROCESSOR' &&
          r.requestType == 'HARVEST_TO_COLLECTION' &&
          r.status == RequestStatus.accepted)
      .toList();

  List<WorkflowRequest> get collectionHistory => _requests
      .where((r) =>
          r.fromRole == 'COLLECTOR_PROCESSOR' ||
          (r.toRole == 'COLLECTOR_PROCESSOR' &&
              (r.status == RequestStatus.completed || r.status == RequestStatus.denied)))
      .toList();

  List<WorkflowRequest> get labPendingRequests => _requests
      .where((r) =>
          r.toRole == 'LAB' &&
          r.requestType == 'COLLECTION_TO_LAB' &&
          (r.status == RequestStatus.pending ||
              r.status == RequestStatus.accepted ||
              r.status == RequestStatus.testing ||
              r.status == RequestStatus.awaitingTest))
      .toList();

  List<WorkflowRequest> get labVerifiedRequests => _requests
      .where((r) =>
          r.requestType == 'COLLECTION_TO_LAB' && r.status == RequestStatus.labApproved)
      .toList();

  List<WorkflowRequest> get labHistory => _requests
      .where((r) =>
          r.fromRole == 'LAB' ||
          (r.toRole == 'LAB' &&
              (r.status == RequestStatus.completed ||
                  r.status == RequestStatus.labApproved ||
                  r.status == RequestStatus.labRejected ||
                  r.status == RequestStatus.denied)))
      .toList();

  List<WorkflowRequest> get packagingPendingRequests => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          r.requestType == 'LAB_TO_PACKAGING' &&
          (r.status == RequestStatus.pending ||
              r.status == RequestStatus.accepted ||
              r.status == RequestStatus.packagingApproved ||
              r.status == RequestStatus.readyForPackaging))
      .toList();

  List<WorkflowRequest> get packagingHistory => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          (r.status == RequestStatus.completed ||
              r.status == RequestStatus.qrGenerated ||
              r.status == RequestStatus.denied))
      .toList();

  // ── Filtered Requests by Direction & Role ──
  List<WorkflowRequest> incomingRequests(String role) {
    final norm = _normalizeRole(role);
    return _requests.where((r) => r.toRole == norm && r.status == RequestStatus.pending).toList();
  }

  List<WorkflowRequest> outgoingRequests(String role) {
    final norm = _normalizeRole(role);
    return _requests.where((r) => r.fromRole == norm).toList();
  }

  List<WorkflowRequest> requestsByStatus(RequestStatus status) {
    return _requests.where((r) => r.status == status).toList();
  }

  String _normalizeRole(String role) {
    final r = role.toUpperCase().trim();
    if (r.contains('COLLECT') || r.contains('PROCESS')) return 'COLLECTOR_PROCESSOR';
    if (r.contains('LAB')) return 'LAB';
    if (r.contains('PKG') || r.contains('PACKAG')) return 'PACKAGING';
    return 'HARVESTER';
  }

  // ── Fetch all data from backend ──
  Future<void> fetchAllData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Try to fetch from /api/requests
      final reqResponse = await _client
          .get(Uri.parse('$apiUrl/requests'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (reqResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(reqResponse.body);
        _requests = data.map((json) => WorkflowRequest.fromJson(json)).toList();
      } else {
        // Fallback: Fetch batches
        await _fetchBatchesFallback();
      }
    } catch (e) {
      debugPrint('[WorkflowController] Error fetching requests: $e. Using fallback.');
      await _fetchBatchesFallback();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchBatchesFallback() async {
    try {
      final response = await _client
          .get(Uri.parse('$apiUrl/batches'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _requests = data.map((json) => WorkflowRequest.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('[WorkflowController] Batches fallback error: $e');
    }
  }

  Future<void> fetchBatches() async => fetchAllData();

  // ── 1. Create Harvest & Send Request to Collection ──
  Future<bool> createHarvestAndRequest({
    required String harvesterName,
    required String location,
    required double quantity,
    String? hiveId,
    String notes = '',
  }) async {
    try {
      // Step 1: Create Harvest & Batch
      final harvestRes = await _client
          .post(
            Uri.parse('$apiUrl/harvests'),
            headers: _headers,
            body: json.encode({
              'harvesterId': harvesterName,
              'hiveId': hiveId ?? 'HC-HIVE-01',
              'quantity': quantity,
              'location': location,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (harvestRes.statusCode == 200 || harvestRes.statusCode == 201) {
        final data = json.decode(harvestRes.body);
        final batchId = data['batch']?['id'];

        if (batchId != null) {
          // Step 2: Create Workflow Request: Harvester -> Collection
          await _client
              .post(
                Uri.parse('$apiUrl/requests'),
                headers: _headers,
                body: json.encode({
                  'batchId': batchId,
                  'harvesterId': harvesterName,
                  'fromRole': 'HARVESTER',
                  'toRole': 'COLLECTOR_PROCESSOR',
                  'requestType': 'HARVEST_TO_COLLECTION',
                  'quantity': quantity,
                  'notes': notes.isNotEmpty ? notes : 'Harvested honey sent to collection',
                }),
              )
              .timeout(const Duration(seconds: 5));
        }

        await fetchAllData();
        return true;
      }
    } catch (e) {
      debugPrint('createHarvestAndRequest error: $e');
      errorMessage = 'Failed to create harvest request: $e';
      notifyListeners();
    }
    return false;
  }

  // ── 2. Accept Request ──
  Future<bool> acceptRequest(String requestId, {String? actorId, String? actorRole, String? notes}) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$apiUrl/requests/$requestId/accept'),
            headers: _headers,
            body: json.encode({
              'actorId': actorId ?? 'Authorized Officer',
              'actorRole': actorRole ?? 'COLLECTOR_PROCESSOR',
              'notes': notes ?? 'Request accepted',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Accept failed';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('acceptRequest error: $e');
      // Optimistic local update
      _updateLocalStatus(requestId, RequestStatus.accepted);
    }
    return false;
  }

  // ── 3. Reject Request ──
  Future<bool> rejectRequest(String requestId, {String? actorId, String? actorRole, required String reason}) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$apiUrl/requests/$requestId/reject'),
            headers: _headers,
            body: json.encode({
              'actorId': actorId ?? 'Authorized Officer',
              'actorRole': actorRole ?? 'COLLECTOR_PROCESSOR',
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Rejection failed';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('rejectRequest error: $e');
      _updateLocalStatus(requestId, RequestStatus.denied, denialReason: reason);
    }
    return false;
  }

  // ── 4. Stage 1 -> Stage 2: Process & Send to Lab ──
  Future<bool> sendToLab({
    required String requestId,
    required String batchId,
    required double qtyReceived,
    required double qtyAfter,
    required String method,
    String? notes,
    String? processorId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/requests/$requestId/send-next'),
            headers: _headers,
            body: json.encode({
              'actorId': processorId ?? 'Processor Officer',
              'actorRole': 'COLLECTOR_PROCESSOR',
              'quantityReceived': qtyReceived,
              'quantityAfter': qtyAfter,
              'method': method,
              'notes': notes ?? 'Batch extracted and sent to Lab for purity analysis',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Failed to send to Lab';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('sendToLab error: $e');
      // Fallback via legacy processing endpoint
      await processBatch(batchId, processorId ?? 'Processor', qtyReceived, qtyAfter, method, notes ?? '');
    }
    return false;
  }

  // Legacy compatibility wrapper
  Future<void> processBatch(String batchId, String processorId, double qtyReceived,
      double qtyAfter, String method, String notes) async {
    try {
      await _client.post(
        Uri.parse('$apiUrl/processing'),
        headers: _headers,
        body: json.encode({
          'batchId': batchId,
          'processorId': processorId,
          'quantityReceived': qtyReceived,
          'quantityAfter': qtyAfter,
          'method': method,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      await fetchAllData();
    } catch (e) {
      debugPrint("Process Batch Error: $e");
    }
  }

  // ── 5. Stage 2: Submit Lab Report ──
  Future<bool> submitLabReport({
    required String requestId,
    required String batchId,
    required double moisture,
    required double purity,
    required double qualityScore,
    String contaminants = 'None',
    String? notes,
    String? labId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/lab-reports'),
            headers: _headers,
            body: json.encode({
              'requestId': requestId,
              'batchId': batchId,
              'labId': labId ?? 'Lab Technician',
              'testResults': 'Moisture: $moisture%, Purity: $purity%, Contaminants: $contaminants',
              'qualityScore': qualityScore,
              'moistureContent': moisture,
              'purityGrade': 'Grade A ($purity%)',
              'contaminantsFound': contaminants,
              'notes': notes ?? 'Certified laboratory report',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Lab report submission failed';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('submitLabReport error: $e');
      _updateLocalStatus(requestId, RequestStatus.labApproved);
    }
    return false;
  }

  // ── 6. Stage 2 -> Stage 3: Lab Approve & Send to Packaging ──
  Future<bool> sendToPackaging({
    required String requestId,
    required String batchId,
    String? notes,
    String? labId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/requests/$requestId/send-next'),
            headers: _headers,
            body: json.encode({
              'actorId': labId ?? 'Lab Quality Officer',
              'actorRole': 'LAB',
              'notes': notes ?? 'Lab verification passed; approved for packaging',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Failed to send to Packaging';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('sendToPackaging error: $e');
      _updateLocalStatus(requestId, RequestStatus.readyForPackaging);
    }
    return false;
  }

  // ── 7. Stage 3: Complete Packaging ──
  Future<bool> finalizePackaging({
    required String requestId,
    required String batchId,
    required double finalQuantity,
    required int numberOfPackages,
    String packageSize = '500g Glass Jar',
    String? notes,
    String? packagerId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/packaging'),
            headers: _headers,
            body: json.encode({
              'requestId': requestId,
              'batchId': batchId,
              'packagerId': packagerId ?? 'Packaging Manager',
              'finalQuantity': finalQuantity,
              'numberOfPackages': numberOfPackages,
              'packageSize': packageSize,
              'notes': notes ?? 'Sealed and packaged with QR verification',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        final err = json.decode(res.body)['error'] ?? 'Packaging finalization failed';
        errorMessage = err;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('finalizePackaging error: $e');
      await completePackaging(batchId, packagerId ?? 'Packager', finalQuantity, numberOfPackages, notes ?? '');
    }
    return false;
  }

  // Legacy packaging wrapper
  Future<void> completePackaging(String batchId, String packagerId, double qty,
      int numPackages, String notes) async {
    try {
      await _client.post(
        Uri.parse('$apiUrl/packaging'),
        headers: _headers,
        body: json.encode({
          'batchId': batchId,
          'packagerId': packagerId,
          'finalQuantity': qty,
          'numberOfPackages': numPackages,
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 5));
      await fetchAllData();
    } catch (e) {
      debugPrint("Packaging Error: $e");
    }
  }

  // ── Fetch Full Batch Workflow & History ──
  Future<Map<String, dynamic>?> fetchBatchWorkflow(String batchId) async {
    try {
      final res = await _client
          .get(Uri.parse('$apiUrl/batches/$batchId/workflow'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (e) {
      debugPrint('fetchBatchWorkflow error: $e');
    }
    return null;
  }

  // ── Local Fallback Updates ──
  void _updateLocalStatus(String id, RequestStatus newStatus, {String? denialReason}) {
    final index = _requests.indexWhere((r) => r.id == id || r.requestId == id);
    if (index != -1) {
      final req = _requests[index];
      _requests[index] = WorkflowRequest(
        id: req.id,
        requestId: req.requestId,
        batchId: req.batchId,
        harvesterName: req.harvesterName,
        fromRole: req.fromRole,
        toRole: req.toRole,
        requestType: req.requestType,
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
        blockchainStatus: req.blockchainStatus,
        labSampleId: req.labSampleId,
        moistureContent: req.moistureContent,
        purityGrade: req.purityGrade,
        contaminantsFound: req.contaminantsFound,
        qualityScore: req.qualityScore,
        labNotes: req.labNotes,
        labReportDate: req.labReportDate,
        packagingApprovedDate: req.packagingApprovedDate,
        qrGenerated: req.qrGenerated,
        denialReason: denialReason ?? req.denialReason,
        history: req.history,
      );
      notifyListeners();
    }
  }

  // UI convenience triggers
  void generateQr(String id) => _updateLocalStatus(id, RequestStatus.qrGenerated);
  void allowPackaging(String id) => _updateLocalStatus(id, RequestStatus.packagingApproved);
  void denyRequest(String id, String reason) => rejectRequest(id, reason: reason);
}

