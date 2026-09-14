import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/hive_alert_model.dart';
import '../services/audio_alert_service.dart';

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
    startMonitoring();
  }

  static String _resolveApiUrl() {
    if (kIsWeb) {
      return '/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {}
    return '/api';
  }

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
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['alerts'] is List) {
          final incoming = (data['alerts'] as List)
              .map((a) => HiveAlertModel.fromJson(a as Map<String, dynamic>))
              .toList();

          _alerts = incoming;

          // Find the newest unacknowledged critical alert not yet dismissed in current session
          final unhandled = incoming.where(
            (a) => a.isCritical && a.isActive && !_acknowledgedAlertIds.contains(a.id),
          ).toList();

          if (unhandled.isNotEmpty) {
            final nextAlert = unhandled.first;
            if (_activeUnacknowledgedAlert?.id != nextAlert.id) {
              _activeUnacknowledgedAlert = nextAlert;
              _isAlertPopupOpen = true;

              // Trigger loud 3-4 consecutive alert beeps
              AudioAlertService.instance.playCriticalAlertBeeps(count: 4);
              notifyListeners();
            }
          } else {
            if (_activeUnacknowledgedAlert != null && !_isAlertPopupOpen) {
              _activeUnacknowledgedAlert = null;
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TelemetryAlertController] Alerts poll error: $e');
    }
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
        headers: {'Content-Type': 'application/json'},
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

  /// Acknowledge the critical alert when the Harvester clicks OK
  Future<void> acknowledgeAlert(String alertId, {String? userId, String? userName}) async {
    // 1. Immediately stop any active beeps
    AudioAlertService.instance.stopAlert();

    _acknowledgedAlertIds.add(alertId);
    _isAlertPopupOpen = false;
    _activeUnacknowledgedAlert = null;
    notifyListeners();

    // 2. Transmit acknowledgement to backend
    try {
      final uri = Uri.parse('$_baseUrl/telemetry/alerts/$alertId/acknowledge');
      await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userName': userName,
        }),
      );
    } catch (e) {
      debugPrint('[TelemetryAlertController] Acknowledge sync error: $e');
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
