import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/match.dart';
import 'package:calmcup/services/world_cup_api_service.dart';

/// Amostra com o MESMO formato do arquivo real da Copa 2026
/// (https://github.com/openfootball/worldcup.json) — horários no formato
/// "HH:MM UTC-6", que antes quebravam o DateTime.parse e geravam o
/// "Erro ao carregar dados".
const _raw2026 = '''
{"name": "World Cup 2026",
 "matches": [
   {"round": "Matchday 1", "date": "2026-06-11", "time": "13:00 UTC-6",
    "team1": "Mexico", "team2": "South Africa", "group": "Group A", "ground": "Mexico City"},
   {"round": "Matchday 1", "date": "2026-06-11", "time": "20:00 UTC-6",
    "team1": "South Korea", "team2": "Czech Republic", "group": "Group A", "ground": "Guadalajara"},
   {"round": "Matchday 2", "date": "2026-06-12", "time": "15:00 UTC-4",
    "team1": "Canada", "team2": "Bosnia & Herzegovina", "group": "Group B", "ground": "Toronto"},
   {"round": "Quarter-final", "date": "2026-07-01", "time": "16:30 UTC-4",
    "team1": "Winner R16-1", "team2": "Winner R16-2", "ground": "Boston"},
   {"round": "Matchday 5", "date": "2026-06-13", "time": "12:00 UTC-7",
    "team1": "USA", "team2": "Panama", "group": "Group D", "ground": "Los Angeles"}
 ]}
''';

void main() {
  final api = WorldCupApiService();

  group('Copa 2026 — parsing dos horários "HH:MM UTC-X"', () {
    test('parseMatchesFromRaw não lança e lê todas as partidas', () {
      final matches = api.parseMatchesFromRaw(_raw2026);
      expect(matches.length, 5);
    });

    test('dateTime converte hora do estádio + fuso para o instante UTC correto',
        () {
      final m = api.parseMatchesFromRaw(_raw2026);
      // 13:00 em UTC-6  => 19:00 UTC
      expect(m[0].dateTime.toUtc(), DateTime.utc(2026, 6, 11, 19, 0));
      // 20:00 em UTC-6  => 02:00 UTC do dia seguinte
      expect(m[1].dateTime.toUtc(), DateTime.utc(2026, 6, 12, 2, 0));
      // 15:00 em UTC-4  => 19:00 UTC
      expect(m[2].dateTime.toUtc(), DateTime.utc(2026, 6, 12, 19, 0));
      // 16:30 em UTC-4  => 20:30 UTC
      expect(m[3].dateTime.toUtc(), DateTime.utc(2026, 7, 1, 20, 30));
      // 12:00 em UTC-7  => 19:00 UTC
      expect(m[4].dateTime.toUtc(), DateTime.utc(2026, 6, 13, 19, 0));
    });

    test('localTimeLabel sempre retorna "HH:MM" para jogos com horário', () {
      final parsed = api.parseMatchesFromRaw(_raw2026);
      for (final m in parsed) {
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(m.localTimeLabel), isTrue,
            reason: 'localTimeLabel inválido para ${m.team1}');
      }
    });
  });

  group('Compatibilidade e casos de borda', () {
    Match make(String date, String time) => Match(
        round: 'X', date: date, time: time, team1: 'A', team2: 'B', ground: 'G');

    test('formato antigo "HH:MM" continua funcionando (hora local)', () {
      final m = make('2018-06-14', '18:00');
      expect(m.dateTime, DateTime(2018, 6, 14, 18, 0));
      expect(m.localTimeLabel, '18:00');
    });

    test('horário vazio não lança e vira meia-noite', () {
      final m = make('2026-06-11', '');
      expect(m.dateTime, DateTime.parse('2026-06-11'));
      expect(m.localTimeLabel, '');
    });

    test('fuso positivo "UTC+2" também é suportado', () {
      // 21:00 em UTC+2 => 19:00 UTC
      final m = make('2026-06-11', '21:00 UTC+2');
      expect(m.dateTime.toUtc(), DateTime.utc(2026, 6, 11, 19, 0));
    });
  });

  group('Regressão: o caminho que causava "Erro ao carregar dados"', () {
    test('iterar dateTime de todas as partidas (como _hasLiveMatch) não lança',
        () {
      final matches = api.parseMatchesFromRaw(_raw2026);
      final now = DateTime.now();
      // Réplica exata do predicado de Copa2026Provider._hasLiveMatch.
      expect(() {
        matches.any((m) {
          final k = m.dateTime;
          return k.isBefore(now) &&
              k.add(const Duration(minutes: 120)).isAfter(now);
        });
      }, returnsNormally);
    });
  });
}
