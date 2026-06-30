import 'package:flutter_test/flutter_test.dart';
import 'package:atv4/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CopaDoMundoApp());
    expect(find.byType(CopaDoMundoApp), findsOneWidget);
  });
}
