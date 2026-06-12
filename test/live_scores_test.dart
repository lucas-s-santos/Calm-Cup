import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/services/world_cup_api_service.dart';

// Times no formato do rezarahiminia (inclui um caso de apelido: United States).
const _rzTeams = '''
[
  {"id": "1", "name_en": "Mexico"},
  {"id": "2", "name_en": "South Africa"},
  {"id": "3", "name_en": "United States"},
  {"id": "4", "name_en": "Paraguay"}
]
''';

// Jogos no formato do rezarahiminia: 1 finalizado, 1 em andamento, 1 não iniciado.
const _rzMatches = '''
[
  {"home_team_id": "1", "away_team_id": "2", "home_score": "2", "away_score": "1",
   "local_date": "06/11/2026 13:00", "finished": "TRUE", "time_elapsed": "finished"},
  {"home_team_id": "3", "away_team_id": "4", "home_score": "1", "away_score": "0",
   "local_date": "06/13/2026 18:00", "finished": "FALSE", "time_elapsed": "57"},
  {"home_team_id": "2", "away_team_id": "3", "home_score": "0", "away_score": "0",
   "local_date": "06/18/2026 12:00", "finished": "FALSE", "time_elapsed": "notstarted"}
]
''';

// openfootball: mesmos jogos, identificados por nome (orientação pode variar).
const _ofMatches = '''
{"name": "World Cup 2026", "matches": [
  {"round": "Matchday 1", "date": "2026-06-11", "time": "13:00 UTC-6",
   "team1": "Mexico", "team2": "South Africa", "group": "Group A", "ground": "Mexico City"},
  {"round": "Matchday 5", "date": "2026-06-13", "time": "12:00 UTC-7",
   "team1": "USA", "team2": "Paraguay", "group": "Group D", "ground": "Los Angeles"},
  {"round": "Matchday 8", "date": "2026-06-18", "time": "12:00 UTC-4",
   "team1": "South Africa", "team2": "USA", "group": "Group A", "ground": "Atlanta"}
]}
''';

void main() {
  final api = WorldCupApiService();

  group('parseLiveScores', () {
    test('inclui finalizados e em andamento; exclui não iniciados', () {
      final scores = api.parseLiveScores(_rzTeams, _rzMatches);
      // 2 jogos válidos x 2 orientações = 4 chaves; o não iniciado fica de fora.
      expect(scores.length, 4);
      expect(scores.containsKey('2026-06-18_South_Africa_USA'), isFalse);
    });

    test('placar do jogo finalizado fica na chave do openfootball', () {
      final scores = api.parseLiveScores(_rzTeams, _rzMatches);
      final s = scores['2026-06-11_Mexico_South_Africa'];
      expect(s, isNotNull);
      expect(s!.ft, [2, 1]);
    });

    test('apelido United States -> USA casa com o openfootball', () {
      final scores = api.parseLiveScores(_rzTeams, _rzMatches);
      final s = scores['2026-06-13_USA_Paraguay'];
      expect(s, isNotNull);
      expect(s!.ft, [1, 0]);
    });

    test('guarda as duas orientações com placar invertido', () {
      final scores = api.parseLiveScores(_rzTeams, _rzMatches);
      expect(scores['2026-06-11_South_Africa_Mexico']!.ft, [1, 2]);
    });
  });

  group('integração: chaves casam com Match.matchKey do openfootball', () {
    test('jogo do openfootball recebe o placar sobreposto', () {
      final ofMatches = api.parseMatchesFromRaw(_ofMatches);
      final live = api.parseLiveScores(_rzTeams, _rzMatches);

      final mex = ofMatches.firstWhere((m) => m.team1 == 'Mexico');
      expect(mex.score, isNull); // openfootball não tem placar
      final merged = live.containsKey(mex.matchKey)
          ? mex.copyWith(score: live[mex.matchKey])
          : mex;
      expect(merged.score?.ft, [2, 1]); // placar sobreposto

      // Jogo não iniciado continua sem placar.
      final notStarted = ofMatches.firstWhere((m) => m.team1 == 'South Africa');
      expect(live.containsKey(notStarted.matchKey), isFalse);
    });
  });
}
