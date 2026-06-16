import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/goal.dart';
import 'package:calmcup/services/world_cup_api_service.dart';

// Reproduz o payload real do openfootball 2026, em que o minuto do gol vem como
// STRING ("9") e o placar como número. Antes da correção, `minute as int`
// lançava "type 'String' is not a subtype of type 'int'" e derrubava todas as
// telas da Copa 2026 com "Erro ao carregar dados".
const _raw = '''
{"name": "World Cup 2026", "matches": [
  {"round": "Matchday 1", "date": "2026-06-11", "time": "13:00 UTC-6",
   "team1": "Mexico", "team2": "South Africa", "group": "Group A",
   "ground": "Mexico City",
   "score": {"ft": [2, 0], "ht": [1, 0]},
   "goals1": [
     {"name": "Julián Quiñones", "minute": "9"},
     {"name": "Breel Embolo", "minute": "45", "offset": "2", "penalty": true}
   ],
   "goals2": []}
]}
''';

void main() {
  final api = WorldCupApiService();

  test('parseia gol com minute em String (payload real openfootball 2026)', () {
    final matches = api.parseMatchesFromRaw(_raw);
    expect(matches, hasLength(1));

    final g = matches.first.goals1;
    expect(g[0].minute, 9);
    expect(g[0].displayMinute, "9'");

    expect(g[1].minute, 45);
    expect(g[1].offset, 2);
    expect(g[1].penalty, isTrue);
    expect(g[1].displayMinute, "45+2'");
  });

  test('placar continua parseando com valores numéricos', () {
    final matches = api.parseMatchesFromRaw(_raw);
    expect(matches.first.score?.ft, [2, 0]);
    expect(matches.first.score?.displayScore, '2 x 0');
  });

  test('Goal.fromJson tolera minute ausente sem lançar', () {
    final g = Goal.fromJson({'name': 'X'});
    expect(g.minute, 0);
    expect(g.offset, isNull);
  });
}
