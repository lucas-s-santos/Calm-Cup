import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/utils/json_parse.dart';
import 'package:calmcup/models/stadium.dart';

void main() {
  group('asIntOrNull', () {
    test('aceita int, num e String numérica', () {
      expect(asIntOrNull(7), 7);
      expect(asIntOrNull('7'), 7);
      expect(asIntOrNull(' 7 '), 7);
      expect(asIntOrNull(7.0), 7);
    });

    test('retorna null para null e texto não numérico', () {
      expect(asIntOrNull(null), isNull);
      expect(asIntOrNull('abc'), isNull);
      expect(asIntOrNull(''), isNull);
    });

    test('asIntOr usa o fallback quando não dá pra converter', () {
      expect(asIntOr('abc', 0), 0);
      expect(asIntOr(null, -1), -1);
      expect(asIntOr('42', 0), 42);
    });
  });

  group('Stadium.fromJson', () {
    test('parseia capacity como número (dados reais do openfootball)', () {
      final s = Stadium.fromJson({
        'city': 'Vancouver',
        'timezone': 'UTC-7',
        'name': 'BC Place',
        'capacity': 54000,
        'coords': '49N 123W',
      });
      expect(s.capacity, 54000);
    });

    test('não quebra se capacity vier como String', () {
      final s = Stadium.fromJson({
        'city': 'X',
        'timezone': 'UTC-5',
        'name': 'Y',
        'capacity': '54000',
        'coords': '0 0',
      });
      expect(s.capacity, 54000);
    });
  });
}
