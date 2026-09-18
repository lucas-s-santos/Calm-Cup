import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/services/openfootball_json_service.dart';

// Reproduz um payload real do football.json (ligas domésticas): jogos
// terminados 0x0 vêm com "score" como um array simples ([0, 0]) em vez do
// objeto padrão {"ft": [...], "ht": [...]} usado no resto do arquivo —
// confirmado contra Premier League, La Liga, Serie A, Bundesliga, Ligue 1 e
// Primeira Liga 2025/26 (dezenas de jogos por liga, não é caso raro). Antes
// da correção, `Score.fromJson(json['score'] as Map<String, dynamic>)`
// lançava "type 'List<dynamic>' is not a subtype of type 'Map<String,
// dynamic>'" e derrubava a tela de qualquer liga com pelo menos um 0x0.
const _raw = '''
{"name": "English Premier League 2025/26", "matches": [
  {"round": "Matchday 1", "date": "2025-08-16", "time": "12:30",
   "team1": "Aston Villa FC", "team2": "Newcastle United FC",
   "score": [0, 0]},
  {"round": "Matchday 1", "date": "2025-08-15", "time": "20:00",
   "team1": "Liverpool FC", "team2": "AFC Bournemouth",
   "score": {"ft": [4, 2], "ht": [1, 0]}}
]}
''';

void main() {
  final api = OpenFootballJsonService();

  test('placar como array simples ([0, 0]) não lança e vira 0x0', () {
    final matches = api.parseMatchesFromRaw(_raw);
    expect(matches, hasLength(2));

    final drawn = matches.first;
    expect(drawn.score?.ft, [0, 0]);
    expect(drawn.score?.ht, isNull);
    expect(drawn.score?.hasResult, isTrue);
    expect(drawn.score?.displayScore, '0 x 0');
  });

  test('placar no formato objeto padrão continua funcionando normalmente', () {
    final matches = api.parseMatchesFromRaw(_raw);
    final normal = matches.last;
    expect(normal.score?.ft, [4, 2]);
    expect(normal.score?.ht, [1, 0]);
  });
}
