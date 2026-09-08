import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const HoneyChainApp());
    expect(find.text('HoneyChain Mobile Application'), findsOneWidget);
  });
}
