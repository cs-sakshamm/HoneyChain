import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/workflow_request.dart';

class WorkflowController extends ChangeNotifier {
  List<WorkflowRequest> _requests = [];
  bool isLoading = false;
  String? errorMessage;
  String? lastErrorCode;
  String? lastSuccessMessage;
  Map<String, dynamic>? lastLabReportResult;

  bool get isProfileIncompleteError => lastErrorCode == 'PROFILE_INCOMPLETE';

  final String apiUrl;
  final http.Client _client;

  WorkflowController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        apiUrl = baseUrl ?? _resolveApiUrl() {
    fetchAllData();
  }

  static String _resolveApiUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return '${AppConstants.backendBaseUrl}/api';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  void clearError() {
    errorMessage = null;
    lastErrorCode = null;
    notifyListeners();
  }

  void _handleErrorResponse(http.Response res, String defaultMessage) {
    try {
      final body = json.decode(res.body);
      lastErrorCode = body['code'];
      errorMessage = body['message'] ?? body['error'] ?? defaultMessage;
    } catch (_) {
      lastErrorCode = null;
      errorMessage = defaultMessage;
    }
    notifyListeners();
  }

  List<WorkflowRequest> get allRequests => List.unmodifiable(_requests);

  // ── Harvester Categorized Requests ──
  List<WorkflowRequest> get harvesterRequests =>
      _requests.where((r) => r.fromRole == 'HARVESTER' || r.requestType == 'HARVEST_TO_COLLECTION').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── Collection & Processing 4 Distinct Categorized Lists ──
  List<WorkflowRequest> get collectionNewRequests => _requests
      .where((r) =>
          r.toRole == 'COLLECTOR_PROCESSOR' &&
          r.requestType == 'HARVEST_TO_COLLECTION' &&
          r.status == RequestStatus.pending)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get collectionAcceptedRequests => _requests
      .where((r) =>
          r.toRole == 'COLLECTOR_PROCESSOR' &&
          r.requestType == 'HARVEST_TO_COLLECTION' &&
          (r.status == RequestStatus.accepted ||
              r.status == RequestStatus.processing))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get collectionRejectedRequests => _requests
      .where((r) =>
          (r.toRole == 'COLLECTOR_PROCESSOR' || r.fromRole == 'COLLECTOR_PROCESSOR') &&
          r.status == RequestStatus.denied)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get collectionCompletedRequests => _requests
      .where((r) =>
          r.fromRole == 'COLLECTOR_PROCESSOR' ||
          (r.toRole == 'COLLECTOR_PROCESSOR' && r.status == RequestStatus.completed))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Legacy aliases for backward compatibility
  List<WorkflowRequest> get pendingCollectionRequests => collectionNewRequests;
  List<WorkflowRequest> get acceptedCollectionRequests => collectionAcceptedRequests;
  List<WorkflowRequest> get collectionHistory => [
        ...collectionCompletedRequests,
        ...collectionRejectedRequests,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── Lab Testing 3 Distinct Categorized Lists ──
  List<WorkflowRequest> get labRequestedRequests => _requests
      .where((r) =>
          r.toRole == 'LAB' &&
          r.requestType == 'COLLECTION_TO_LAB' &&
          r.status == RequestStatus.pending)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get labAcceptedRequests => _requests
      .where((r) =>
          r.toRole == 'LAB' &&
          r.requestType == 'COLLECTION_TO_LAB' &&
          (r.status == RequestStatus.accepted ||
              r.status == RequestStatus.testing ||
              r.status == RequestStatus.awaitingTest))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get labCompletedRequests => _requests
      .where((r) =>
          r.toRole == 'LAB' &&
          (r.status == RequestStatus.labApproved ||
              r.status == RequestStatus.completed ||
              r.status == RequestStatus.labRejected ||
              r.status == RequestStatus.denied))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Legacy aliases
  List<WorkflowRequest> get labPendingRequests => [
        ...labRequestedRequests,
        ...labAcceptedRequests,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<WorkflowRequest> get labVerifiedRequests => _requests
      .where((r) => r.requestType == 'COLLECTION_TO_LAB' && r.status == RequestStatus.labApproved)
      .toList();
  List<WorkflowRequest> get labHistory => labCompletedRequests;

  // ── Packaging 4 Distinct Categorized Lists ──
  List<WorkflowRequest> get packagingRequestedRequests => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          r.requestType == 'LAB_TO_PACKAGING' &&
          r.status == RequestStatus.pending)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get packagingAcceptedRequests => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          r.requestType == 'LAB_TO_PACKAGING' &&
          (r.status == RequestStatus.accepted ||
              r.status == RequestStatus.readyForPackaging ||
              r.status == RequestStatus.packagingApproved))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get packagingProcessingRequests => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          r.status == RequestStatus.processing)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get packagingCompletedRequests => _requests
      .where((r) =>
          r.toRole == 'PACKAGING' &&
          (r.status == RequestStatus.completed ||
              r.status == RequestStatus.qrGenerated ||
              r.status == RequestStatus.denied))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Legacy aliases
  List<WorkflowRequest> get packagingPendingRequests => [
        ...packagingRequestedRequests,
        ...packagingAcceptedRequests,
        ...packagingProcessingRequests,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<WorkflowRequest> get packagingHistory => packagingCompletedRequests;

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

  // ── Fetch all requests from backend ──
  Future<void> fetchAllData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final reqResponse = await _client
          .get(Uri.parse('$apiUrl/requests'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (reqResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(reqResponse.body);
        _requests = data.map((json) => WorkflowRequest.fromJson(json)).toList();
      } else {
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

  // ── 0. Fetch Nearest Verified Centres with Distance (KM) ──
  Future<List<Map<String, dynamic>>> fetchNearestCenters({
    required String targetRole,
    double? lat,
    double? lng,
    String? originLocation,
    String? originHiveId,
    String? batchId,
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{
        'role': targetRole,
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
        if (originLocation != null && originLocation.isNotEmpty) 'originLocation': originLocation,
        if (originHiveId != null && originHiveId.isNotEmpty) 'originHiveId': originHiveId,
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final uri = Uri.parse('$apiUrl/centers/nearest').replace(queryParameters: queryParams);
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> centers = data['centers'] ?? [];
        return centers.map((c) => Map<String, dynamic>.from(c)).toList();
      }
    } catch (e) {
      debugPrint('[WorkflowController] fetchNearestCenters error: $e');
    }
    return [];
  }

  // ── 1. Create Harvest & Send Request to Target Collection Centre ──
  Future<bool> createHarvestAndRequest({
    required String harvesterName,
    required String location,
    required double quantity,
    String? targetCollectorId,
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
              if (hiveId != null) 'hiveId': hiveId,
              'quantity': quantity,
              'location': location,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (harvestRes.statusCode == 200 || harvestRes.statusCode == 201) {
        final data = json.decode(harvestRes.body);
        final batchId = data['batchId'] ?? data['batch']?['id'] ?? data['batch']?['batch_id'] ?? data['id'];

        if (batchId != null) {
          // Step 2: Create Workflow Request targeting specific collection center
          final reqRes = await _client
              .post(
                Uri.parse('$apiUrl/requests'),
                headers: _headers,
                body: json.encode({
                  'batchId': batchId,
                  'harvesterId': harvesterName,
                  'toUserId': targetCollectorId,
                  'fromRole': 'HARVESTER',
                  'toRole': 'COLLECTOR_PROCESSOR',
                  'requestType': 'HARVEST_TO_COLLECTION',
                  'quantity': quantity,
                  'notes': notes.isNotEmpty ? notes : 'Harvested honey sent to nearest collection center',
                }),
              )
              .timeout(const Duration(seconds: 5));

          if (reqRes.statusCode == 200 || reqRes.statusCode == 201) {
            await fetchAllData();
            return true;
          } else {
            _handleErrorResponse(reqRes, 'Failed to create collection request');
            return false;
          }
        }
      } else {
        _handleErrorResponse(harvestRes, 'Failed to create harvest record');
        return false;
      }
    } catch (e) {
      debugPrint('createHarvestAndRequest error: $e');
    }
    return false;
  }

  // ── 2. Accept Workflow Request ──
  Future<bool> acceptRequest(
    String requestId, {
    String? actorId,
    String? actorRole,
    String? notes,
  }) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$apiUrl/requests/$requestId/accept'),
            headers: _headers,
            body: json.encode({
              if (actorId != null) 'actorId': actorId,
              if (actorRole != null) 'actorRole': actorRole,
              if (notes != null) 'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        _updateLocalStatus(requestId, RequestStatus.accepted);
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Failed to accept request');
        return false;
      }
    } catch (e) {
      debugPrint('acceptRequest error: $e');
      errorMessage = 'Network error while accepting request';
      notifyListeners();
      return false;
    }
  }

  // ── 3. Reject Workflow Request ──
  Future<bool> rejectRequest(
    String requestId, {
    String? actorId,
    String? actorRole,
    String? reason,
  }) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$apiUrl/requests/$requestId/reject'),
            headers: _headers,
            body: json.encode({
              if (actorId != null) 'actorId': actorId,
              if (actorRole != null) 'actorRole': actorRole,
              'reason': reason ?? 'Rejected by reviewer',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        _updateLocalStatus(requestId, RequestStatus.denied);
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Failed to reject request');
        return false;
      }
    } catch (e) {
      debugPrint('rejectRequest error: $e');
      errorMessage = 'Network error while rejecting request';
      notifyListeners();
      return false;
    }
  }

  // ── 4. Stage 1 -> Stage 2: Process & Send to Target Lab ──
  Future<bool> sendToLab({
    required String requestId,
    required String batchId,
    required double qtyReceived,
    required double qtyAfter,
    required String method,
    String? targetLabId,
    double? moisture,
    String? notes,
    String? processorId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/requests/$requestId/send-next'),
            headers: _headers,
            body: json.encode({
              'actorId': processorId ?? 'Processor',
              'actorRole': 'COLLECTOR_PROCESSOR',
              if (targetLabId != null) 'toUserId': targetLabId,
              'quantityReceived': qtyReceived,
              'quantityAfter': qtyAfter,
              'method': method,
              'moistureAtReceipt': moisture,
              'notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Failed to send batch to Lab');
        return false;
      }
    } catch (e) {
      debugPrint('sendToLab error: $e');
    }
    return false;
  }

  // ── 5. Stage 2: Submit Lab Report ──
  Future<bool> submitLabReport({
    required String requestId,
    required String batchId,
    required double moisture,
    required double purity,
    required double qualityScore,
    double? hmfValue,
    double? diastaseValue,
    String? residuesValue,
    String? pollenValue,
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
              'testResults': 'Moisture: $moisture%, Purity: $purity, Score: $qualityScore/100',
              'qualityScore': qualityScore,
              'moistureContent': moisture,
              'moistureValue': moisture,
              'hmfValue': hmfValue ?? 12.4,
              'diastaseValue': diastaseValue ?? 14.2,
              'purityValue': purity,
              'residuesValue': residuesValue ?? 'None Detected',
              'pollenValue': pollenValue ?? 'Authentic Floral Matrix',
              'purityGrade': 'Grade A',
              'contaminantsFound': contaminants,
              'notes': notes ?? 'Certified laboratory report',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        try {
          lastLabReportResult = json.decode(res.body) as Map<String, dynamic>?;
        } catch (_) {}
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Lab report submission failed');
        return false;
      }
    } catch (e) {
      debugPrint('submitLabReport error: $e');
    }
    return false;
  }

  // ── 6. Stage 2 -> Stage 3: Lab Approve & Send to Target Packaging Centre ──
  Future<bool> sendToPackaging({
    required String requestId,
    required String batchId,
    String? targetPackagerId,
    String? notes,
    String? labId,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$apiUrl/requests/$requestId/send-next'),
            headers: _headers,
            body: json.encode({
              'actorId': labId ?? 'Lab Officer',
              'actorRole': 'LAB',
              if (targetPackagerId != null) 'toUserId': targetPackagerId,
              'notes': notes ?? 'Lab approved; forwarded to packaging facility',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Failed to send to Packaging');
        return false;
      }
    } catch (e) {
      debugPrint('sendToPackaging error: $e');
    }
    return false;
  }

  // ── 7. Stage 3: Finalize Packaging & Issue QR ──
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
              'packagerId': packagerId ?? 'Packager',
              'finalQuantity': finalQuantity,
              'numberOfPackages': numberOfPackages,
              'packageSize': packageSize,
              'notes': notes ?? 'Bottled in sterile ISO facility with tamper-evident seal',
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        await fetchAllData();
        return true;
      } else {
        _handleErrorResponse(res, 'Failed to finalize packaging');
        return false;
      }
    } catch (e) {
      debugPrint('finalizePackaging error: $e');
    }
    return false;
  }

  // ── 8. Update Request Status directly / Start Processing ──
  Future<bool> updateRequestStatus(String requestId, RequestStatus newStatus) async {
    try {
      final res = await _client
          .patch(
            Uri.parse('$apiUrl/requests/$requestId/status'),
            headers: _headers,
            body: json.encode({'status': newStatus.name}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _updateLocalStatus(requestId, newStatus);
        await fetchAllData();
        return true;
      }
    } catch (e) {
      debugPrint('updateRequestStatus error: $e');
    }
    return false;
  }

  // ── 9. Fetch Full Batch Verification / Provenance ──
  Future<Map<String, dynamic>?> fetchBatchWorkflow(String batchId) async {
    try {
      final res = await _client
          .get(Uri.parse('$apiUrl/verify?batch=$batchId'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (e) {
      debugPrint('fetchBatchWorkflow error: $e');
    }
    return null;
  }

  void _updateLocalStatus(String requestId, RequestStatus newStatus) {
    final index = _requests.indexWhere((r) => r.id == requestId || r.requestId == requestId);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }
}
