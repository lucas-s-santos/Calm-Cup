import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calmcup/services/local_storage_service.dart';

/// O cache bruto por URL é a base do modo offline das competições do catálogo
/// (Brasileirão, Champions, ligas...): sem ele, cada tela dessas virava um
/// erro de rede em vez de mostrar os últimos dados baixados.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocalStorageService cache bruto por URL', () {
    const url =
        'https://raw.githubusercontent.com/openfootball/football.json/master/2025-26/en.1.json';

    test('URL nunca baixada não tem cache', () async {
      expect(await LocalStorageService().loadRawByUrl(url), isNull);
    });

    test('devolve exatamente o texto salvo', () async {
      const raw = '{"matches":[{"round":"Matchday 1"}]}';
      final storage = LocalStorageService();

      await storage.saveRawByUrl(url, raw);

      expect(await storage.loadRawByUrl(url), raw);
    });

    test('cada URL tem seu próprio cache (uma competição não sobrescreve outra)',
        () async {
      const outraUrl =
          'https://raw.githubusercontent.com/openfootball/football.json/master/2025-26/es.1.json';
      final storage = LocalStorageService();

      await storage.saveRawByUrl(url, 'premier');
      await storage.saveRawByUrl(outraUrl, 'la liga');

      expect(await storage.loadRawByUrl(url), 'premier');
      expect(await storage.loadRawByUrl(outraUrl), 'la liga');
    });

    test('salvar de novo substitui o cache anterior da mesma URL', () async {
      final storage = LocalStorageService();

      await storage.saveRawByUrl(url, 'antigo');
      await storage.saveRawByUrl(url, 'novo');

      expect(await storage.loadRawByUrl(url), 'novo');
    });

    test('o cache bruto não colide com os resultados salvos pela pessoa',
        () async {
      final storage = LocalStorageService();

      await storage.saveRawByUrl(url, 'json da liga');
      await storage.saveResult('2026-06-11_Mexico_Brazil', 1, 2);

      expect(await storage.loadRawByUrl(url), 'json da liga');
      final results = await storage.getAllResults();
      expect(results.keys, ['2026-06-11_Mexico_Brazil']);
    });
  });
}
