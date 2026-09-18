import '../models/match.dart';

/// Estatísticas simples derivadas de uma lista de partidas de UM campeonato —
/// usado pela aba Estatísticas quando o campeonato selecionado não é a Copa
/// do Mundo (histórico já coberto por `HistoryProvider`, com sua própria
/// lógica por já agregar várias edições). Recebe sempre a lista de um único
/// campeonato/edição — quem decide quais partidas entram é o chamador,
/// então nunca mistura números de campeonatos diferentes.

/// Artilheiros — só reflete algo quando a fonte informa gol a gol
/// (`goals1`/`goals2`, hoje só Copa do Mundo e Eurocopa). Ligas domésticas e
/// as fontes em texto (Brasileirão, Libertadores, Champions atual, Copa
/// América) só têm o placar final, então retorna lista vazia — a tela deve
/// esconder a seção em vez de fingir que o dado existe.
List<Map<String, dynamic>> topScorers(Iterable<Match> matches, {int limit = 10}) {
  final Map<String, int> scorers = {};
  for (final m in matches) {
    for (final g in [...m.goals1, ...m.goals2]) {
      if (!g.ownGoal) scorers[g.name] = (scorers[g.name] ?? 0) + 1;
    }
  }
  final list = scorers.entries
      .map((e) => {'name': e.key, 'goals': e.value})
      .toList()
    ..sort((a, b) => (b['goals'] as int).compareTo(a['goals'] as int));
  return list.take(limit).toList();
}

/// Jogos com mais gols (placar final) — funciona pra qualquer fonte, já que
/// só depende do placar, não de gol a gol.
List<Map<String, dynamic>> highestScoringMatches(Iterable<Match> matches,
    {int limit = 5}) {
  final all = <Map<String, dynamic>>[];
  for (final m in matches) {
    if (m.score?.hasResult == true) {
      final total = m.score!.ft[0] + m.score!.ft[1];
      all.add({'match': m, 'total': total});
    }
  }
  all.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
  return all.take(limit).toList();
}

/// Total de gols e partidas com resultado — base pros cards de resumo.
Map<String, int> matchStatsSummary(Iterable<Match> matches) {
  int totalGoals = 0;
  int totalMatches = 0;
  for (final m in matches) {
    if (m.score?.hasResult == true) {
      totalGoals += m.score!.ft[0] + m.score!.ft[1];
      totalMatches++;
    }
  }
  return {'goals': totalGoals, 'matches': totalMatches};
}

/// Gols marcados/sofridos e jogos disputados por time (só partidas com
/// resultado) — base pra "Melhor Ataque"/"Melhor Defesa".
List<Map<String, dynamic>> teamGoalStats(Iterable<Match> matches) {
  final Map<String, Map<String, int>> stats = {};
  void bump(String team, String key, int value) {
    final s =
        stats.putIfAbsent(team, () => {'scored': 0, 'conceded': 0, 'played': 0});
    s[key] = s[key]! + value;
  }

  for (final m in matches) {
    if (m.score?.hasResult != true) continue;
    final g1 = m.score!.ft[0];
    final g2 = m.score!.ft[1];
    bump(m.team1, 'scored', g1);
    bump(m.team1, 'conceded', g2);
    bump(m.team1, 'played', 1);
    bump(m.team2, 'scored', g2);
    bump(m.team2, 'conceded', g1);
    bump(m.team2, 'played', 1);
  }

  return stats.entries.map((e) => {'team': e.key, ...e.value}).toList();
}

/// Quantos jogos (com resultado) o mandante venceu, o visitante venceu, ou
/// empataram — aproveitamento casa x fora da competição inteira.
Map<String, int> homeAwayRecord(Iterable<Match> matches) {
  int home = 0, away = 0, draw = 0;
  for (final m in matches) {
    if (m.score?.hasResult != true) continue;
    final g1 = m.score!.ft[0];
    final g2 = m.score!.ft[1];
    if (g1 > g2) {
      home++;
    } else if (g2 > g1) {
      away++;
    } else {
      draw++;
    }
  }
  return {'home': home, 'away': away, 'draw': draw};
}

/// Maior sequência de vitórias seguidas entre os times da competição (por
/// ordem cronológica das partidas com resultado). `null` quando ninguém
/// chega a 2 vitórias seguidas (dado pouco interessante pra mostrar).
Map<String, dynamic>? longestWinStreak(Iterable<Match> matches) {
  final sorted = matches.where((m) => m.score?.hasResult == true).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final current = <String, int>{};
  final best = <String, int>{};

  void update(String team, bool won) {
    if (won) {
      final next = (current[team] ?? 0) + 1;
      current[team] = next;
      if (next > (best[team] ?? 0)) best[team] = next;
    } else {
      current[team] = 0;
    }
  }

  for (final m in sorted) {
    final g1 = m.score!.ft[0];
    final g2 = m.score!.ft[1];
    update(m.team1, g1 > g2);
    update(m.team2, g2 > g1);
  }

  if (best.isEmpty) return null;
  final top = best.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (top.value < 2) return null;
  return {'team': top.key, 'streak': top.value};
}
