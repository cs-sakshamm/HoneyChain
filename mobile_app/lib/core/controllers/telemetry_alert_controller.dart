import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/hive_alert_model.dart';
import '../models/hive_telemetry_models.dart';
import '../services/audio_alert_service.dart';
import '../services/auth_token_store.dart';

/// Real-Time Telemetry & Critical Sudden Change Alert Controller for Harvesters
class TelemetryAlertController extends ChangeNotifier {
  final http.Client _client;
  final String _baseUrl;
  Timer? _pollingTimer;

  List<HiveAlertModel> _alerts = [];
  HiveAlertModel? _activeUnacknowledgedAlert;
  final Set<String> _acknowledgedAlertIds = {};
  bool _isMonitoring = false;
  bool _isAlertPopupOpen = false;

  List<HiveAlertModel> get alerts => _alerts;
  HiveAlertModel? get activeUnacknowledgedAlert => _activeUnacknowledgedAlert;
  bool get isMonitoring => _isMonitoring;
  bool get isAlertPopupOpen => _isAlertPopupOpen;

  TelemetryAlertController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveApiUrl() {
    // Wait for the UI to call startMonitoring with the correct userId
  }

  static String _resolveApiUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return '${AppConstants.backendBaseUrl}/api';
  }

  /// Backend requests carry the signed JWT issued at login.
  Map<String, String> _authHeaders() => {
        'Accept': 'application/json',
        ...AuthTokenStore.authHeader(),
      };

  /// Starts real-time monitoring of live hive telemetry alerts
  void startMonitoring({String? userId, Duration interval = const Duration(seconds: 4)}) {
    _isMonitoring = true;
    _pollingTimer?.cancel();
    fetchAlerts(userId: userId);

    _pollingTimer = Timer.periodic(interval, (_) {
      fetchAlerts(userId: userId);
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Fetch active alerts from the backend
  Future<void> fetchAlerts({String? userId}) async {
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/alerts').replace(
        queryParameters: {
          if (userId != null && userId.isNotEmpty) 'userId': userId,
          'status': 'ACTIVE',
        },
      );

      final response = await _client.get(
        uri,
        headers: _authHeaders(),
      );

      if (response.statusCode == 200) {
        final bodyText = response.body.trim();
        if (bodyText.startsWith('{') || bodyText.startsWith('[')) {
          final data = json.decode(bodyText);
          if (data['success'] == true && data['alerts'] is List) {
            final incoming = (data['alerts'] as List)
                .map((a) => HiveAlertModel.fromJson(a as Map<String, dynamic>))
                .toList();

            _alerts = incoming;

            // Newest unacknowledged critical alert. A local "seen" memory
            // only prevents re-beeping for an alert the user already saw
            // this session while the backend still lists it as ACTIVE —
            // the modal itself always reflects authoritative backend state.
            final unhandled = incoming.where(
              (a) => a.isCritical && a.isActive && !_acknowledgedAlertIds.contains(a.id),
            ).toList();

            if (unhandled.isNotEmpty) {
              final nextAlert = unhandled.first;
              final isNewAlert = _activeUnacknowledgedAlert?.id != nextAlert.id;
              _activeUnacknowledgedAlert = nextAlert;
              _isAlertPopupOpen = true;

              // Beep only when a genuinely NEW alert takes the stage;
              // polling must never restart sound for the same alert.
              if (isNewAlert) {
                AudioAlertService.instance.playCriticalAlertBeeps(count: 4);
              }
              notifyListeners();
            } else {
              if (_activeUnacknowledgedAlert != null && !_isAlertPopupOpen) {
                _activeUnacknowledgedAlert = null;
                notifyListeners();
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Alerts poll error: $e');
    }
  }

  /// Fetch recent live telemetry history for a specific hive
  Future<List<Map<String, dynamic>>> fetchHiveTelemetry(String hiveId) async {
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/live/$hiveId');
      final response = await _client.get(uri, headers: _authHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['telemetry'] is List) {
          return List<Map<String, dynamic>>.from(data['telemetry']);
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Telemetry history fetch error: $e');
    }
    return [];
  }

  /// Latest real telemetry + stored AI status for one hive.
  /// Returns null only when the backend is unreachable or rejects the token —
  /// callers distinguish "no telemetry yet" via HiveSnapshot.hasTelemetry.
  Future<HiveSnapshot?> fetchHiveSnapshot(String hiveId) async {
    try {
      final uri = Uri.parse('$_baseUrl/hives/$hiveId/telemetry/latest');
      final response = await _client.get(uri, headers: _authHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return HiveSnapshot.fromJson(data);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[TelemetryAlertController] Snapshot unauthorized (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Snapshot fetch error: $e');
    }
    return null;
  }

  /// Stored AI/ML status for one hive (risk, anomaly, readiness toward the
  /// ~145-reading history the AI feature builder requires).
  Future<HiveAiStatusBundle?> fetchHiveStatus(String hiveId) async {
    try {
      final uri = Uri.parse('$_baseUrl/hives/$hiveId/status');
      final response = await _client.get(uri, headers: _authHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return HiveAiStatusBundle.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Status fetch error: $e');
    }
    return null;
  }

  /// Historical telemetry (newest first) from the backend.
  Future<List<Map<String, dynamic>>> fetchHiveTelemetryHistory(String hiveId, {int limit = 144}) async {
    try {
      final uri = Uri.parse('$_baseUrl/hives/$hiveId/telemetry').replace(
        queryParameters: {'limit': '$limit'},
      );
      final response = await _client.get(uri, headers: _authHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true && data['telemetry'] is List) {
          return List<Map<String, dynamic>>.from(data['telemetry'] as List);
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Telemetry history fetch error: $e');
    }
    return [];
  }

  /// Ingests sensor data directly (used by simulator or local tests)
  Future<HiveAlertModel?> ingestSensorData({
    required String hiveId,
    required double temperature,
    required double humidity,
    required double weightKg,
    double beeActivity = 85.0,
    double? soundFrequencyHz,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/ingest');
      final response = await _client.post(
        uri,
        headers: _authHeaders(),
        body: json.encode({
          'hiveId': hiveId,
          'temperature': temperature,
          'humidity': humidity,
          'weightKg': weightKg,
          'beeActivity': beeActivity,
          'soundFrequencyHz': soundFrequencyHz,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['alerts'] is List && (data['alerts'] as List).isNotEmpty) {
          final newAlert = HiveAlertModel.fromJson((data['alerts'] as List).first);
          _activeUnacknowledgedAlert = newAlert;
          _isAlertPopupOpen = true;
          _alerts.insert(0, newAlert);

          AudioAlertService.instance.playCriticalAlertBeeps(count: 4);
          notifyListeners();
          return newAlert;
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Ingest error: $e');
    }
    return null;
  }

  /// Acknowledge the critical alert when the Harvester taps OK.
  ///
  /// Order of operations (spec §6): stop the sound immediately, close the
  /// modal optimistically, then let the BACKEND authorize and persist the
  /// acknowledgment. Local memory only prevents the poller from re-beeping
  /// if the backend is briefly unreachable — the backend remains the single
  /// source of truth for alert state.
  Future<bool> acknowledgeAlert(String alertId, {String? userId, String? userName}) async {
    // 1. Immediately stop any active beeps
    AudioAlertService.instance.stopAlert();

    _acknowledgedAlertIds.add(alertId);
    _isAlertPopupOpen = false;
    _activeUnacknowledgedAlert = null;
    notifyListeners();

    // 2. Backend acknowledgment is authoritative (authenticated owner only).
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/alerts/$alertId/acknowledge');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ..._authHeaders(),
        },
        body: json.encode({
          'userId': userId,
          'userName': userName,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      debugPrint('[TelemetryAlertController] Acknowledge rejected: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[TelemetryAlertController] Acknowledge sync error: $e');
      return false;
    }
  }

  void markPopupClosed() {
    _isAlertPopupOpen = false;
    AudioAlertService.instance.stopAlert();
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    AudioAlertService.instance.stopAlert();
    super.dispose();
  }
}
