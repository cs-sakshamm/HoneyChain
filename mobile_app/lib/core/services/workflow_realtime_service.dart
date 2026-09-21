import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import 'auth_token_store.dart';

/// Realtime channel for workflow request events.
///
/// Connects to the FastAPI WebSocket endpoint with the session JWT, receives
/// role/user-targeted events (request_created / request_updated), and hands
/// them to the WorkflowController so dashboards update without polling.
///
/// Reliability contract:
/// - The DATABASE (via REST) remains the source of truth. Events are only a
///   hint to refetch; losing them never loses data.
/// - Automatic reconnection with capped exponential backoff.
/// - On reconnect the controller re-fetches everything, so requests created
///   while offline appear immediately.
/// - Pings keep intermediaries from idling the socket out.
class WorkflowRealtimeService {
  WorkflowRealtimeService({VoidCallback? onEvent}) : _onEvent = onEvent;

  final VoidCallback? _onEvent;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connectedOnce = false;
  int _reconnectAttempt = 0;

  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _baseBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 30);

  bool get isConnected => _channel != null;

  Uri _resolveUri() {
    final base = AppConstants.backendBaseUrl;
    final wsBase = base.replaceFirst(RegExp(r'^http'), 'ws');
    final token = AuthTokenStore.token ?? '';
    return Uri.parse('$wsBase/ws?token=$token');
  }

  void connect() {
    if (_disposed || !AuthTokenStore.hasToken) return;
    // Never stack two sockets.
    _cleanupSocket();

    try {
      final channel = WebSocketChannel.connect(_resolveUri());
      _channel = channel;

      _subscription = channel.stream.listen(
        (data) {
          // Any workflow event means dashboards should reflect the latest
          // backend state. The controller decides what to refresh.
          _onEvent?.call();
        },
        onDone: _scheduleReconnect,
        onError: (Object e) {
          debugPrint('[Realtime] WebSocket error: $e');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // App-level heartbeat (server answers PONG).
      _pingTimer = Timer.periodic(_pingInterval, (_) {
        try {
          _channel?.sink.add(jsonEncode({'event': 'PING'}));
        } catch (_) {}
      });

      _connectedOnce = true;
      _reconnectAttempt = 0;
      if (kDebugMode) debugPrint('[Realtime] WebSocket connected');
    } catch (e) {
      debugPrint('[Realtime] WebSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  /// Force a fresh refetch + socket check after coming back online.
  void resync() {
    if (_disposed) return;
    if (!isConnected) connect();
    _onEvent?.call();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _cleanupSocket();
    if (!_connectedOnce) return; // never connected: caller manages lifecycle

    final delay = _baseBackoff * (1 << _reconnectAttempt.clamp(0, 5));
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 5);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay > _maxBackoff ? _maxBackoff : delay, () {
      if (!_disposed) connect();
    });
  }

  void _cleanupSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectedOnce = false;
    _cleanupSocket();
  }

  void dispose() {
    _disposed = true;
    disconnect();
  }
}
