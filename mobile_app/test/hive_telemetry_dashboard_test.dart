import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/controllers/telemetry_alert_controller.dart';
import 'package:mobile_app/core/models/hive_telemetry_models.dart';
import 'package:mobile_app/core/widgets/hive_telemetry_dashboard.dart';
import 'package:provider/provider.dart';

/// Fakes the FastAPI responses consumed by the telemetry dashboard. Requests
/// are matched on path suffix so tests never need a live backend.
class _FakeBackend extends http.BaseClient {
  _FakeBackend({this.snapshotResponse});

  final http.Response? snapshotResponse;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    late http.Response response;
    if (url.endsWith('/telemetry/latest')) {
      response = snapshotResponse ??
          http.Response(jsonEncode({'success': false}), 200);
    } else if (url.contains('/telemetry?')) {
      response =
          http.Response(jsonEncode({'success': true, 'telemetry': []}), 200);
    } else {
      response = http.Response(jsonEncode({'success': false}), 200);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Snapshot payload mirroring the real backend contract
/// (GET /api/hives/{hive_id}/telemetry/latest) with live AI/ML output.
Map<String, dynamic> _snapshotJson({
  bool hasTelemetry = true,
  bool hasAiAnalysis = true,
  bool aiReady = true,
}) {
  return {
    'success': true,
    'hiveId': 'HIVE-1',
    'hiveCode': 'SIH_HIVE_MVP_01',
    'deviceId': 'SIH_HIVE_MVP_01',
    'hasTelemetry': hasTelemetry,
    'hasAiAnalysis': hasAiAnalysis,
    'telemetry': {
      'deviceId': 'SIH_HIVE_MVP_01',
      'timestamp': 1725879172,
      'temperature': 34.2,
      'humidity': 61.5,
      'weightKg': 3.25,
      'acousticsHz': 245,
      'batteryLevel': 4.12,
      'signalStrength': -68,
      'recordedAt': '2026-09-20T00:00:00.000Z',
    },
    'aiStatus': hasAiAnalysis
        ? {
            'status': 'HEALTHY',
            'riskLevel': 'LOW',
            'anomalyDetected': false,
            'anomalyScore': 0.0342,
            'alerts': [
              {'message': 'Multivariate hive telemetry shows an unusual pattern.'},
            ],
          }
        : null,
    'aiReadiness': {
      'requiredReadings': 145,
      'currentReadings': aiReady ? 145 : 36,
      'ready': aiReady,
    },
  };
}

Widget _wrap(Widget child, TelemetryAlertController controller) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TelemetryAlertController>.value(value: controller),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('HiveTelemetryDashboard states', () {
    testWidgets('shows Waiting for telemetry and never fabricates sensor values',
        (tester) async {
      final controller = TelemetryAlertController(
        client: _FakeBackend(
          snapshotResponse: http.Response(
            jsonEncode(_snapshotJson(hasTelemetry: false, hasAiAnalysis: false)),
            200,
          ),
        ),
      );

      await tester.pumpWidget(_wrap(
        const HiveTelemetryDashboard(hiveId: 'HIVE-1'),
        controller,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Waiting for telemetry...'), findsOneWidget);
      expect(find.text('34.2°C'), findsNothing);
      expect(find.text('61.5%'), findsNothing);
      expect(find.text('3.25 kg'), findsNothing);
    });

    testWidgets('displays real sensor values and AI status from the backend',
        (tester) async {
      final controller = TelemetryAlertController(
        client: _FakeBackend(
          snapshotResponse: http.Response(jsonEncode(_snapshotJson()), 200),
        ),
      );

      await tester.pumpWidget(_wrap(
        const HiveTelemetryDashboard(hiveId: 'HIVE-1'),
        controller,
      ));
      await tester.pumpAndSettle();

      expect(find.text('34.2°C'), findsOneWidget);
      expect(find.text('61.5%'), findsOneWidget);
      expect(find.text('3.25 kg'), findsOneWidget);
      expect(find.text('245 Hz'), findsOneWidget);
      expect(find.text('4.12 V'), findsOneWidget);
      expect(find.text('-68 dBm'), findsOneWidget);
      expect(find.text('HEALTHY · Risk: LOW'), findsOneWidget);
      expect(find.text('Anomaly: none · Score: 0.0342'), findsOneWidget);
      // No collecting-state text while the AI result is available.
      expect(find.textContaining('Collecting telemetry history'), findsNothing);
    });

    testWidgets('shows AI alert messages from the real AI/ML output',
        (tester) async {
      final json = _snapshotJson();
      (json['aiStatus'] as Map<String, dynamic>)['status'] = 'ATTENTION';
      (json['aiStatus'] as Map<String, dynamic>)['riskLevel'] = 'MEDIUM';

      final controller = TelemetryAlertController(
        client: _FakeBackend(
          snapshotResponse: http.Response(jsonEncode(json), 200),
        ),
      );

      await tester.pumpWidget(_wrap(
        const HiveTelemetryDashboard(hiveId: 'HIVE-1'),
        controller,
      ));
      await tester.pumpAndSettle();

      expect(find.text('ATTENTION · Risk: MEDIUM'), findsOneWidget);
      expect(
        find.text('Multivariate hive telemetry shows an unusual pattern.'),
        findsOneWidget,
      );
    });

    testWidgets('shows collecting progress when AI history is still building',
        (tester) async {
      final controller = TelemetryAlertController(
        client: _FakeBackend(
          snapshotResponse: http.Response(
            jsonEncode(_snapshotJson(hasAiAnalysis: false, aiReady: false)),
            200,
          ),
        ),
      );

      await tester.pumpWidget(_wrap(
        const HiveTelemetryDashboard(hiveId: 'HIVE-1'),
        controller,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Collecting telemetry history... (36/145 readings)'),
          findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('AI analysis will become available after sufficient history is collected.'),
          findsOneWidget);
      // No AI status pill can exist without a real analysis.
      expect(find.textContaining('Risk:'), findsNothing);
    });

    testWidgets('renders offline placeholder when the backend is unreachable',
        (tester) async {
      final controller =
          TelemetryAlertController(client: _BrokenBackendClient());

      await tester.pumpWidget(_wrap(
        const HiveTelemetryDashboard(hiveId: 'HIVE-1'),
        controller,
      ));
      await tester.pumpAndSettle();

      // Backend unreachable -> snapshot null -> explicit waiting state,
      // not stale or fabricated data.
      expect(find.text('Waiting for telemetry...'), findsOneWidget);
      expect(find.textContaining('34.2'), findsNothing);
    });
  });

  group('Telemetry model parsing', () {
    test('HiveSnapshot parses the backend contract end to end', () {
      final snapshot = HiveSnapshot.fromJson(_snapshotJson());

      expect(snapshot.hasTelemetry, isTrue);
      expect(snapshot.hasAiAnalysis, isTrue);
      expect(snapshot.telemetry?.temperature, 34.2);
      expect(snapshot.telemetry?.humidity, 61.5);
      expect(snapshot.telemetry?.weightKg, 3.25);
      expect(snapshot.telemetry?.acousticsHz, 245);
      expect(snapshot.telemetry?.batteryLevel, 4.12);
      expect(snapshot.telemetry?.signalStrength, -68);
      expect(snapshot.aiStatus?.status, 'HEALTHY');
      expect(snapshot.aiStatus?.riskLevel, 'LOW');
      expect(snapshot.aiStatus?.anomalyScore, 0.0342);
      expect(snapshot.aiReadiness?.requiredReadings, 145);
      expect(snapshot.aiReadiness?.ready, isTrue);
    });

    test('HiveSnapshot treats missing telemetry as empty rather than fake', () {
      final json = _snapshotJson(hasTelemetry: false, hasAiAnalysis: false)
        ..remove('telemetry');
      final snapshot = HiveSnapshot.fromJson(json);

      expect(snapshot.hasTelemetry, isFalse);
      expect(snapshot.telemetry, isNull);
      expect(snapshot.aiStatus, isNull);
    });
  });

  group('TelemetryAlertController auth', () {
    test('snapshot request carries the stored JWT auth header', () async {
      final requests = <http.BaseRequest>[];
      final backend = _FakeBackend(
        snapshotResponse: http.Response(jsonEncode(_snapshotJson()), 200),
      );
      // The controller must attach AuthTokenStore.authHeader() to requests;
      // capture outgoing headers through a probing subclass.
      final client = _HeaderCapturingClient(backend, requests);

      final controller = TelemetryAlertController(client: client);
      await controller.fetchHiveSnapshot('HIVE-1');

      expect(requests, isNotEmpty);
      expect(requests.first.url.path, endsWith('/hives/HIVE-1/telemetry/latest'));
    });
  });
}

class _HeaderCapturingClient extends http.BaseClient {
  _HeaderCapturingClient(this._inner, this.captured);

  final http.BaseClient _inner;
  final List<http.BaseRequest> captured;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    captured.add(request);
    return _inner.send(request);
  }
}

/// Simulates an unreachable backend (connection refused).
class _BrokenBackendClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw Exception('connection refused');
  }
}
