import 'package:flutter_test/flutter_test.dart';
import 'package:safeprep/main.dart';

void main() {
  testWidgets('smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafePrepApp());
  });
}