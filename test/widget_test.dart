import 'package:flutter_test/flutter_test.dart';
import 'package:uniplan/main.dart';

void main() {
  testWidgets('UniPlan app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UniPlanApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Masuk ke UniPlan'), findsOneWidget);
  });
}
