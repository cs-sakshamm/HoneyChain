import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/models/hive_alert_model.dart';
import 'package:mobile_app/core/widgets/critical_alert_dialog.dart';

void main() {
  group('HiveAlertModel Serialization & Parsing Tests', () {
    test('Correctly parses critical alert JSON payload with temperature jump', () {
      final json = {
        'id': 'ALERT-TEMP-001',
        'hiveId': 'HIVE-TEST-001',
        'hiveCode': 'HIVE_001',
        'parameter': 'Temperature',
        'previousValue': '32.4°C',
        'currentValue': '39.8°C',
        'changeValue': '+7.4°C',
        'unit': '°C',
        'severity': 'CRITICAL',
        'message': 'Sudden change detected in Hive HIVE_001',
        'status': 'ACTIVE',
        'detectedAt': DateTime.now().toIso8601String(),
      };

      final alert = HiveAlertModel.fromJson(json);

      expect(alert.id, 'ALERT-TEMP-001');
      expect(alert.hiveCode, 'HIVE_001');
      expect(alert.parameter, 'Temperature');
      expect(alert.previousValue, '32.4°C');
      expect(alert.currentValue, '39.8°C');
      expect(alert.changeValue, '+7.4°C');
      expect(alert.severity, 'CRITICAL');
      expect(alert.isCritical, isTrue);
      expect(alert.isActive, isTrue);
    });
  });

  group('CriticalAlertDialog Widget Tests', () {
    testWidgets('CriticalAlertDialog renders unignorable modal with full parameter details', (WidgetTester tester) async {
      bool acknowledged = false;

      final alert = HiveAlertModel(
        id: 'ALERT-001',
        hiveId: 'HIVE-001',
        hiveCode: 'HIVE_001',
        parameter: 'Temperature',
        previousValue: '32.4°C',
        currentValue: '39.8°C',
        changeValue: '+7.4°C',
        unit: '°C',
        severity: 'CRITICAL',
        message: 'Sudden change detected in Hive HIVE_001',
        status: 'ACTIVE',
        detectedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CriticalAlertDialog(
              alert: alert,
              onAcknowledge: () {
                acknowledged = true;
              },
            ),
          ),
        ),
      );

      // Verify all required prompt text elements exist
      expect(find.text('CRITICAL HIVE ALERT'), findsOneWidget);
      expect(find.text('Sudden change detected in HIVE_001'), findsOneWidget);
      expect(find.text('Parameter:'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Previous Value:'), findsOneWidget);
      expect(find.text('32.4°C'), findsOneWidget);
      expect(find.text('Current Value:'), findsOneWidget);
      expect(find.text('39.8°C'), findsOneWidget);
      expect(find.text('Change:'), findsOneWidget);
      expect(find.text('+7.4°C'), findsOneWidget);
      expect(find.text('Please check the hive immediately.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Tap OK button
      await tester.tap(find.byKey(const Key('critical_alert_ok_button')));
      await tester.pump();

      expect(acknowledged, isTrue);
    });
  });
}
