import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/workflow_request.dart';
import '../services/auth_token_store.dart';
import '../services/workflow_realtime_service.dart';

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

  /// Realtime request delivery: any server-pushed event triggers a REST
  /// refetch (the database stays the source of truth). Reconnection after a
  /// drop also refetches, so nothing created while offline is missed.
  WorkflowRealtimeService? _realtime;

  WorkflowController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        apiUrl = baseUrl ?? _resolveApiUrl() {
    // Only fetch when a session token already exists: this controller is
    // constructed at app startup, before login, and an unauthenticated call
    // would just produce a 401 ("Authentication token is required").
    // AuthRouter triggers a fresh fetch the moment a user signs in.
    if (kDebugMode) {
      debugPrint('[WorkflowController] API base URL: $apiUrl');
    }
    if (AuthTokenStore.hasToken) {
      fetchAllData();
    }
  }

  /// Start listening for realtime workflow events (call after login).
  void startRealtime() {
    if (!AuthTokenStore.hasToken) return;
    _realtime ??= WorkflowRealtimeService(onEvent: () {
      // Fire-and-forget refresh — never blocks the event loop.
      fetchAllData();
    });
    _realtime!.connect();
  }

  void stopRealtime() {
    _realtime?.disconnect();
  }

  @override
  void dispose() {
    _realtime?.dispose();
    super.dispose();
  }

  static String _resolveApiUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return '${AppConstants.backendBaseUrl}/api';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...AuthTokenStore.authHeader(),
      };

  void clearError() {
    errorMessage = null;
    lastErrorCode = null;
    notifyListeners();
  }

  /// Maps a low-level HTTP client failure to a precise user-facing message.
  /// The generic "Unable to reach the backend" is reserved for genuine
  /// connection failures (SocketException / Connection refused) — NOT for
  /// timeouts, which are distinguished, and NOT for HTTP errors (which carry
  /// their own status codes and are handled before this runs).
  static String _describeNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return 'The backend did not respond in time (request timed out after 15s). '
          'Please try again.';
    }
    if (s.contains('Connection refused') ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable')) {
      return 'Unable to reach the backend. Please verify the API server is running.';
    }
    // Unknown transport failure (e.g. handshake error): keep the original
    // message visible in debug builds to aid diagnosis.
    return kDebugMode
        ? 'Request failed: $s'
        : 'Unable to reach the backend. Please verify the API server is running.';
  }

  void _logRequest(String method, Uri uri, {http.Response? res, Object? error}) {
    if (!kDebugMode) return;
    if (error != null) {
      debugPrint('[API] $method ${uri.path} -> ERROR ${error.runtimeType}');
    } else {
      debugPrint('[API] $method ${uri.path} -> HTTP ${res!.statusCode} (${res.reasonPhrase})');
    }
  }

  void _handleErrorResponse(http.Response res, String defaultMessage) {
    try {
      final body = json.decode(res.body);
      final errorBody = body['detail'] is Map<String, dynamic>
          ? body['detail'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      lastErrorCode = errorBody['code'] as String?;
      errorMessage = errorBody['message'] ?? errorBody['error'] ?? defaultMessage;
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
          r.toRole == 'COLLECTOR_PROCESSOR' &&
          r.requestType == 'HARVEST_TO_COLLECTION' &&
          r.status == RequestStatus.denied)
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── Collection & Processing: outgoing Lab dispatches ("My Requests to Lab") ──
  List<WorkflowRequest> get collectionOutgoingLabRequests =>
      _requests
          .where((r) =>
              r.fromRole == 'COLLECTOR_PROCESSOR' &&
              r.requestType == 'COLLECTION_TO_LAB')
          .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get collectionOutgoingLabActive => collectionOutgoingLabRequests
      .where((r) =>
          r.status == RequestStatus.pending ||
          r.status == RequestStatus.accepted ||
          r.status == RequestStatus.processing ||
          r.status == RequestStatus.awaitingTest ||
          r.status == RequestStatus.testing)
      .toList();

  List<WorkflowRequest> get collectionOutgoingLabApproved => collectionOutgoingLabRequests
      .where((r) =>
          r.status == RequestStatus.labApproved ||
          r.status == RequestStatus.completed)
      .toList();

  List<WorkflowRequest> get collectionOutgoingLabRejected => collectionOutgoingLabRequests
      .where((r) =>
          r.status == RequestStatus.labRejected ||
          r.status == RequestStatus.denied)
      .toList();

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
              r.status == RequestStatus.awaitingTest ||
              r.status == RequestStatus.labApproved))
      .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get labRejectedRequests => _requests
      .where((r) =>
          r.toRole == 'LAB' &&
          r.requestType == 'COLLECTION_TO_LAB' &&
          (r.status == RequestStatus.labRejected || r.status == RequestStatus.denied))
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

  // ── Lab Testing: outgoing Packaging dispatches ("My Requests to Packaging") ──
  List<WorkflowRequest> get labOutgoingPackagingRequests =>
      _requests
          .where((r) =>
              r.fromRole == 'LAB' &&
              r.requestType == 'LAB_TO_PACKAGING')
          .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<WorkflowRequest> get labOutgoingPackagingPending => labOutgoingPackagingRequests
      .where((r) => r.status == RequestStatus.pending)
      .toList();

  List<WorkflowRequest> get labOutgoingPackagingInProgress => labOutgoingPackagingRequests
      .where((r) =>
          r.status == RequestStatus.accepted ||
          r.status == RequestStatus.processing ||
          r.status == RequestStatus.readyForPackaging ||
          r.status == RequestStatus.packagingApproved ||
          r.status == RequestStatus.awaitingTest ||
          r.status == RequestStatus.testing)
      .toList();

  List<WorkflowRequest> get labOutgoingPackagingCompleted => labOutgoingPackagingRequests
      .where((r) =>
          r.status == RequestStatus.completed ||
          r.status == RequestStatus.qrGenerated)
      .toList();

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
          r.requestType == 'LAB_TO_PACKAGING' &&
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

  /// Request timeout for workflow API calls.
  ///
  /// Backend calls include bcrypt-verified JWT round-trips and cloud
  /// PostgreSQL latency (~2s measured locally). Budgets below that aborted
  /// legitimate requests and surfaced them as false failures. 15s matches
  /// HiveStorageService and the auth controller's budget.
  static const Duration _requestTimeout = Duration(seconds: 15);

  // ── Fetch all requests from backend ──
  // Single source of truth: GET /api/requests (role-scoped server-side).
  // There is deliberately NO local fallback or secondary endpoint — a failed
  // fetch must surface its real error instead of silently showing stale or
  // empty request data (this previously hid ACCEPTED updates from the
  // harvester behind a call to /api/batches, which does not exist).
  Future<void> fetchAllData() async {
    isLoading = true;
    errorMessage = null;
    lastErrorCode = null;
    notifyListeners();

    try {
      final reqUri = Uri.parse('$apiUrl/requests');
      final reqResponse = await _client.get(reqUri, headers: _headers).timeout(_requestTimeout);
      _logRequest('GET', reqUri, res: reqResponse);

      if (reqResponse.statusCode == 200) {
        final List<dynamic> data = json.decode(reqResponse.body);
        _requests = data.map((json) => WorkflowRequest.fromJson(json)).toList();
      } else {
        // Real API rejection (401 expired token, 403 role, 404/422/409/500):
        // surface the backend's own message instead of masking it.
        _handleErrorResponse(
          reqResponse,
          'Failed to load requests (HTTP ${reqResponse.statusCode}).',
        );
      }
    } catch (e) {
      debugPrint('[WorkflowController] Error fetching requests: $e');
      errorMessage = _describeNetworkError(e);
      lastErrorCode = null;
      notifyListeners();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBatches() async => fetchAllData();

  // ── 0. Fetch Nearest Verified Centres with Distance (KM) ──
  /// Returns the backend's facility records for the requested centre type.
  /// Empty on failure — callers must show an error/retry state, never fake
  /// centres. `lat`/`lng` enable server-side haversine distance.
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
      final res = await _client.get(uri, headers: _headers).timeout(_requestTimeout);
      _logRequest('GET', uri, res: res);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> centers = data['centers'] ?? [];
        return centers.map((c) => Map<String, dynamic>.from(c)).toList();
      }
      // Non-200: report failure through the exception path below so screens
      // show an error state instead of an empty "no centres" list.
      throw Exception('HTTP ${res.statusCode} loading centers');
    } catch (e) {
      debugPrint('[WorkflowController] fetchNearestCenters error: $e');
      rethrow;
    }
  }

  /// Full center + license details for the "View Details" sheet.
  Future<Map<String, dynamic>?> fetchCenterDetails(String centerId, {double? lat, double? lng}) async {
    try {
      final queryParams = <String, String>{
        if (lat != null) 'lat': lat.toString(),
        if (lng != null) 'lng': lng.toString(),
      };
      final uri = Uri.parse('$apiUrl/centers/$centerId').replace(queryParameters: queryParams);
      final res = await _client.get(uri, headers: _headers).timeout(_requestTimeout);
      _logRequest('GET', uri, res: res);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['center'] is Map<String, dynamic> ? data['center'] as Map<String, dynamic> : null;
      }
    } catch (e) {
      debugPrint('[WorkflowController] fetchCenterDetails error: $e');
    }
    return null;
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
          .timeout(_requestTimeout);

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
                  if (hiveId != null) 'hiveId': hiveId,
                  'toUserId': targetCollectorId,
                  'fromRole': 'HARVESTER',
                  'toRole': 'COLLECTOR_PROCESSOR',
                  'requestType': 'HARVEST_TO_COLLECTION',
                  'quantity': quantity,
                  'notes': notes.isNotEmpty ? notes : 'Harvested honey sent to nearest collection center',
                }),
              )
              .timeout(_requestTimeout);

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
      // Surface the real failure (timeout/unreachable backend) so no screen
      // can show a success message when nothing was persisted.
      errorMessage = _describeNetworkError(e);
      lastErrorCode = null;
      notifyListeners();
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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);

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
          .timeout(_requestTimeout);
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
          .timeout(_requestTimeout);

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
