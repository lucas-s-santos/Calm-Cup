import '../models/match.dart';

/// Calcula a tabela de classificação (pontos/V/E/D/gols/saldo) a partir de
/// uma lista de partidas. `scoreOf` decide o placar de cada jogo — permite
/// tanto ler `Match.score` direto (competições só de leitura) quanto
/// sobrepor um resultado manual/simulado, sem esta função precisar saber de
/// onde vem o placar. Retorna `null` para jogos ainda sem resultado (são
/// ignorados no cálculo, mas não impedem os times de aparecerem via
/// `knownTeams`).
///
/// Extraído de `Copa2026Provider.getGroupStandings` e
/// `SimulatorProvider.computeAllStandings`, que tinham essa matemática
/// duplicada palavra por palavra.
List<Map<String, dynamic>> computeStandings(
  List<Match> matches, {
  required List<int>? Function(Match match) scoreOf,
  Iterable<String> knownTeams = const [],
}) {
  final Map<String, Map<String, int>> stats = {};

  void addTeam(String team) {
    stats.putIfAbsent(
        team, () => {'pts': 0, 'pj': 0, 'v': 0, 'e': 0, 'd': 0, 'gp': 0, 'gc': 0});
  }

  for (final team in knownTeams) {
    addTeam(team);
  }

  for (final match in matches) {
    final result = scoreOf(match);
    if (result == null) continue;
    final g1 = result[0], g2 = result[1];

    addTeam(match.team1);
    addTeam(match.team2);

    stats[match.team1]!['pj'] = stats[match.team1]!['pj']! + 1;
    stats[match.team2]!['pj'] = stats[match.team2]!['pj']! + 1;
    stats[match.team1]!['gp'] = stats[match.team1]!['gp']! + g1;
    stats[match.team1]!['gc'] = stats[match.team1]!['gc']! + g2;
    stats[match.team2]!['gp'] = stats[match.team2]!['gp']! + g2;
    stats[match.team2]!['gc'] = stats[match.team2]!['gc']! + g1;

    if (g1 > g2) {
      stats[match.team1]!['pts'] = stats[match.team1]!['pts']! + 3;
      stats[match.team1]!['v'] = stats[match.team1]!['v']! + 1;
      stats[match.team2]!['d'] = stats[match.team2]!['d']! + 1;
    } else if (g1 == g2) {
      stats[match.team1]!['pts'] = stats[match.team1]!['pts']! + 1;
      stats[match.team2]!['pts'] = stats[match.team2]!['pts']! + 1;
      stats[match.team1]!['e'] = stats[match.team1]!['e']! + 1;
      stats[match.team2]!['e'] = stats[match.team2]!['e']! + 1;
    } else {
      stats[match.team2]!['pts'] = stats[match.team2]!['pts']! + 3;
      stats[match.team2]!['v'] = stats[match.team2]!['v']! + 1;
      stats[match.team1]!['d'] = stats[match.team1]!['d']! + 1;
    }
  }

  final list = stats.entries.map((e) {
    final sg = e.value['gp']! - e.value['gc']!;
    return {'team': e.key, ...e.value, 'sg': sg};
  }).toList();

  list.sort((a, b) {
    int cmp = (b['pts'] as int).compareTo(a['pts'] as int);
    if (cmp != 0) return cmp;
    cmp = (b['sg'] as int).compareTo(a['sg'] as int);
    if (cmp != 0) return cmp;
    return (b['gp'] as int).compareTo(a['gp'] as int);
  });

  return list;
}
