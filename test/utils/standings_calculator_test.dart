import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/match.dart';
import 'package:calmcup/models/score.dart';
import 'package:calmcup/utils/standings_calculator.dart';

Match _played(String team1, String team2, int g1, int g2) {
  return Match(
    round: 'Matchday 1',
    date: '2026-06-20',
    time: '16:00',
    team1: team1,
    team2: team2,
    ground: 'Estádio',
    score: Score(ft: [g1, g2]),
  );
}

Match _unplayed(String team1, String team2) {
  return Match(
    round: 'Matchday 2',
    date: '2026-06-27',
    time: '16:00',
    team1: team1,
    team2: team2,
    ground: 'Estádio',
  );
}

List<int>? _scoreOf(Match m) => m.score?.hasResult == true
    ? [m.score!.ft[0], m.score!.ft[1]]
    : null;

void main() {
  group('computeStandings', () {
    test('soma pontos, vitórias, saldo e gols pró/contra corretamente', () {
      final matches = [
        _played('Brazil', 'Argentina', 2, 0), // Brazil V
        _played('Argentina', 'Brazil', 1, 1), // empate
      ];

      final table = computeStandings(matches, scoreOf: _scoreOf);
      final brazil = table.firstWhere((r) => r['team'] == 'Brazil');
      final argentina = table.firstWhere((r) => r['team'] == 'Argentina');

      expect(brazil['pj'], 2);
      expect(brazil['v'], 1);
      expect(brazil['e'], 1);
      expect(brazil['d'], 0);
      expect(brazil['gp'], 3);
      expect(brazil['gc'], 1);
      expect(brazil['sg'], 2);
      expect(brazil['pts'], 4); // 3 (vitória) + 1 (empate)

      expect(argentina['pj'], 2);
      expect(argentina['v'], 0);
      expect(argentina['e'], 1);
      expect(argentina['d'], 1);
      expect(argentina['pts'], 1);
    });

    test('ordena por pontos, depois saldo de gols, depois gols pró', () {
      final matches = [
        _played('A', 'B', 3, 0), // A: 3pts sg+3 · B: 0pts sg-3
        _played('C', 'D', 1, 0), // C: 3pts sg+1 · D: 0pts sg-1
      ];

      final table = computeStandings(matches, scoreOf: _scoreOf);
      // A e C empatam em pontos (3), A vence no saldo (+3 > +1).
      // B e D empatam em pontos (0), D vence no saldo (-1 > -3).
      expect(table.map((r) => r['team']), ['A', 'C', 'D', 'B']);
    });

    test('ignora partidas sem resultado ainda', () {
      final matches = [_unplayed('Brazil', 'Argentina')];
      final table = computeStandings(matches, scoreOf: _scoreOf);
      expect(table, isEmpty);
    });

    test('knownTeams garante que times sem jogo disputado apareçam com zero', () {
      final matches = [_unplayed('Brazil', 'Argentina')];
      final table = computeStandings(
        matches,
        scoreOf: _scoreOf,
        knownTeams: const ['Brazil', 'Argentina'],
      );

      expect(table.length, 2);
      for (final row in table) {
        expect(row['pj'], 0);
        expect(row['pts'], 0);
      }
    });

    test('scoreOf customizado permite sobrepor placar simulado', () {
      final match = _unplayed('Brazil', 'Argentina');
      final simulated = <String, List<int>>{match.matchKey: [2, 1]};

      final table = computeStandings(
        [match],
        scoreOf: (m) => simulated[m.matchKey],
      );

      final brazil = table.firstWhere((r) => r['team'] == 'Brazil');
      expect(brazil['pts'], 3);
    });
  });
}
