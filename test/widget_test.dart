import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:calmcup/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mesma inicialização que main() faz antes de runApp() — sem isso, as
    // telas que formatam data em pt_BR já no primeiro build lançam
    // LocaleDataException.
    await initializeDateFormatting('pt_BR', null);

    await tester.pumpWidget(const CopaDoMundoApp());
    expect(find.byType(CopaDoMundoApp), findsOneWidget);
  });
}
