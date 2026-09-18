import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/match.dart';
import '../providers/competition_provider.dart';
import '../providers/history_provider.dart';
import '../utils/match_stats.dart' as match_stats;
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import '../widgets/team_badge.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loaded = false;

  // null = Copa do Mundo (histórico 1930–2022, via HistoryProvider — dados
  // ricos com artilheiros de todas as edições). Qualquer outro valor mostra
  // estatísticas só daquela competição/edição corrente, sem misturar com o
  // histórico da Copa nem com as demais.
  Competition? _selected;
  final Map<String, CompetitionProvider> _providers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<HistoryProvider>().loadStatsYears();
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final p in _providers.values) {
      p.dispose();
    }
    super.dispose();
  }

  CompetitionProvider _providerFor(Competition c) =>
      _providers.putIfAbsent(c.id, () => CompetitionProvider(c));

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final switcher = PopupMenuButton<Competition?>(
      tooltip: 'Trocar campeonato',
      icon: const Icon(Icons.swap_horiz, color: Colors.white),
      onSelected: (c) => setState(() => _selected = c),
      itemBuilder: (context) => [
        const PopupMenuItem<Competition?>(
          value: null,
          child: Text('🏆 Copa do Mundo (histórico)'),
        ),
        const PopupMenuDivider(),
        ...competitionsCatalog.map((c) => PopupMenuItem<Competition?>(
              value: c,
              child: Text('${c.emoji} ${c.name}'),
            )),
      ],
    );

    if (selected != null) {
      final provider = _providerFor(selected);
      return ListenableBuilder(
        listenable: provider,
        builder: (context, _) => Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text('📊 ${selected.name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [switcher],
          ),
          body: provider.loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFD700)))
              : _CompetitionStatsView(
                  matches: provider.matches,
                  competition: selected,
                ),
        ),
      );
    }

    final provider = context.watch<HistoryProvider>();
    final titles = provider.titlesByCountry;
    final goalsByYear = provider.goalsByYear;
    final sortedTitles = titles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('📊 Estatísticas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [switcher],
      ),
      body: !_loaded
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFD700)),
                  SizedBox(height: 16),
                  Text('Carregando dados históricos...',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Cards resumo ──────────────────────────────────────────
                _SummaryCards(stats: provider.globalStats),
                const SizedBox(height: 24),

                // ── Títulos por País ──────────────────────────────────────
                _SectionTitle(title: '🏆 Títulos por País'),
                const SizedBox(height: 8),
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (sortedTitles.first.value + 1).toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final country = sortedTitles[groupIndex].key;
                            return BarTooltipItem(
                              '$country\n${rod.toY.toInt()} título(s)',
                              const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= sortedTitles.length) {
                                return const SizedBox();
                              }
                              final flag =
                                  _champFlag(sortedTitles[idx].key);
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(flag,
                                    style: const TextStyle(fontSize: 18)),
                              );
                            },
                            reservedSize: 36,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            reservedSize: 24,
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.white12, strokeWidth: 1),
                        drawVerticalLine: false,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: sortedTitles.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value.toDouble(),
                              color: const Color(0xFFFFD700),
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Gols por Edição ───────────────────────────────────────
                if (goalsByYear.isNotEmpty) ...[
                  _SectionTitle(title: '⚽ Gols por Edição'),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _GoalsLineChart(goalsByYear: goalsByYear),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Artilheiros Históricos ────────────────────────────────
                if (provider.allTimeTopScorers.isNotEmpty) ...[
                  _SectionTitle(title: '🥇 Artilheiros Históricos'),
                  const SizedBox(height: 8),
                  _TopScorersCard(scorers: provider.allTimeTopScorers),
                  const SizedBox(height: 24),
                ],

                // ── Jogos mais Goleados ───────────────────────────────────
                if (provider.highestScoringMatches.isNotEmpty) ...[
                  _SectionTitle(title: '🔥 Jogos mais Goleados'),
                  const SizedBox(height: 8),
                  _HighScoringCard(
                    matches: provider.highestScoringMatches,
                    caption: (item) {
                      final m = item['match'] as Match;
                      return 'Copa ${item['year']}  •  ${TeamNamesPt.round(m.round)}';
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Países com mais Participações ─────────────────────────
                if (provider.participationsByCountry.isNotEmpty) ...[
                  _SectionTitle(title: '🌍 Países com mais Participações'),
                  const SizedBox(height: 8),
                  _ParticipationsCard(
                      participations: provider.participationsByCountry),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 8),
              ],
            ),
    );
  }

  String _champFlag(String country) {
    const flags = {
      'Brasil': '🇧🇷',
      'Alemanha': '🇩🇪',
      'Itália': '🇮🇹',
      'Argentina': '🇦🇷',
      'França': '🇫🇷',
      'Uruguai': '🇺🇾',
      'Inglaterra': '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
      'Espanha': '🇪🇸',
    };
    return flags[country] ?? '🏆';
  }
}

// ── Cards de Resumo ───────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final Map<String, int> stats;
  const _SummaryCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: '⚽',
          label: 'Gols',
          value: '${stats['goals'] ?? 0}',
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: '🎮',
          label: 'Partidas',
          value: '${stats['matches'] ?? 0}',
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: '🏆',
          label: 'Edições',
          value: '${stats['editions'] ?? 0}',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF202020),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Artilheiros Históricos ────────────────────────────────────────────────────

class _TopScorersCard extends StatelessWidget {
  final List<Map<String, dynamic>> scorers;
  const _TopScorersCard({required this.scorers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: scorers.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final name = s['name'] as String;
          final goals = s['goals'] as int;
          final medals = ['🥇', '🥈', '🥉'];
          final medal = i < 3 ? medals[i] : '${i + 1}.';
          final isLast = i == scorers.length - 1;

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: i > 0
                  ? const Border(top: BorderSide(color: Colors.white12))
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(11))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(11))
                      : null,
              color: i == 0
                  ? const Color(0xFFFFD700).withValues(alpha: 0.06)
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 30,
                    child: Text(medal,
                        style: TextStyle(
                            fontSize: i < 3 ? 18 : 13,
                            color: Colors.white54))),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$goals ⚽',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Jogos mais Goleados ───────────────────────────────────────────────────────

class _HighScoringCard extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final String Function(Map<String, dynamic> item) caption;
  final String? competitionId;
  const _HighScoringCard(
      {required this.matches, required this.caption, this.competitionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: matches.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final m = item['match'];
          final total = item['total'] as int;
          final ft = m.score.ft as List<int>;
          final n1 = TeamNamesPt.translate(m.team1 as String);
          final n2 = TeamNamesPt.translate(m.team2 as String);
          final isLast = i == matches.length - 1;

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: i > 0
                  ? const Border(top: BorderSide(color: Colors.white12))
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(11))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(11))
                      : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text('$total',
                          style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Text('gols',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TeamBadge(
                              teamName: m.team1 as String,
                              competitionId: competitionId,
                              size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text(n1,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${ft[0]} – ${ft[1]}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          TeamBadge(
                              teamName: m.team2 as String,
                              competitionId: competitionId,
                              size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text(n2,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(caption(item),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Participações por País ────────────────────────────────────────────────────

class _ParticipationsCard extends StatelessWidget {
  final Map<String, int> participations;
  const _ParticipationsCard({required this.participations});

  @override
  Widget build(BuildContext context) {
    final entries = participations.entries.toList();
    final maxVal = entries.isEmpty ? 1 : entries.first.value;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final country = entry.value.key;
          final count = entry.value.value;
          final flag = TeamFlags.get(country);
          final name = TeamNamesPt.translate(country);
          final barFraction = count / maxVal;
          final isLast = i == entries.length - 1;

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: i > 0
                  ? const Border(top: BorderSide(color: Colors.white12))
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(11))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(11))
                      : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                if (flag.isNotEmpty) ...[
                  Text(flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                ],
                SizedBox(
                  width: 100,
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barFraction,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalsLineChart extends StatelessWidget {
  final Map<int, int> goalsByYear;
  const _GoalsLineChart({required this.goalsByYear});

  @override
  Widget build(BuildContext context) {
    final sorted = goalsByYear.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();

    final maxY = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (sorted.length - 1).toDouble(),
        minY: 0,
        maxY: (maxY + 20).toDouble(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${sorted[s.x.toInt()].key}\n${s.y.toInt()} gols',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sorted.length) return const SizedBox();
                return Text(
                  '${sorted[idx].key}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                );
              },
              reservedSize: 24,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
              reservedSize: 30,
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white12, strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFFFD700),
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ── Estatísticas de um campeonato específico (não a Copa histórica) ───────────
//
// Só o que dá pra derivar do placar (todas as fontes) mais artilheiros
// quando a fonte informa gol a gol (só Copa/Euro, via JSON) — sem inventar
// dado que a fonte não tem, e sem misturar números de campeonatos diferentes.

class _CompetitionStatsView extends StatelessWidget {
  final List<Match> matches;
  final Competition competition;
  const _CompetitionStatsView(
      {required this.matches, required this.competition});

  @override
  Widget build(BuildContext context) {
    final summary = match_stats.matchStatsSummary(matches);
    final scorers = match_stats.topScorers(matches);
    final biggest = match_stats.highestScoringMatches(matches);
    final goalStats = match_stats.teamGoalStats(matches)
      ..removeWhere((s) => (s['played'] as int) < 3);
    final homeAway = match_stats.homeAwayRecord(matches);
    final streak = match_stats.longestWinStreak(matches);
    final played = summary['matches'] ?? 0;
    final avgGoals = played > 0 ? (summary['goals']! / played) : 0.0;

    if (played == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ainda não há jogos com resultado nesta competição/temporada.',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bestAttack = [...goalStats]
      ..sort((a, b) => (b['scored'] as int).compareTo(a['scored'] as int));
    final bestDefense = [...goalStats]
      ..sort((a, b) => (a['conceded'] as int).compareTo(b['conceded'] as int));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatCard(icon: '🎮', label: 'Jogos', value: '$played'),
            const SizedBox(width: 8),
            _StatCard(icon: '⚽', label: 'Gols', value: '${summary['goals']}'),
            const SizedBox(width: 8),
            _StatCard(
                icon: '📊',
                label: 'Média/jogo',
                value: avgGoals.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 24),
        if (scorers.isNotEmpty) ...[
          _SectionTitle(title: '🥇 Artilheiros'),
          const SizedBox(height: 8),
          _TopScorersCard(scorers: scorers),
          const SizedBox(height: 24),
        ],
        _SectionTitle(title: '🔥 Maiores Goleadas'),
        const SizedBox(height: 8),
        _HighScoringCard(
          matches: biggest,
          competitionId: competition.id,
          caption: (item) => TeamNamesPt.round((item['match'] as Match).round),
        ),
        if (scorers.isEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Esta fonte de dados só informa o placar final, sem gol a gol — '
            'por isso não há artilheiros aqui.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
        if (bestAttack.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionTitle(title: '⚔️ Melhor Ataque'),
          const SizedBox(height: 8),
          _TeamGoalStatsCard(
            teams: bestAttack.take(3).toList(),
            competitionId: competition.id,
            valueKey: 'scored',
            valueLabel: 'gols pró',
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: '🛡️ Melhor Defesa'),
          const SizedBox(height: 8),
          _TeamGoalStatsCard(
            teams: bestDefense.take(3).toList(),
            competitionId: competition.id,
            valueKey: 'conceded',
            valueLabel: 'gols sofridos',
          ),
        ],
        if (homeAway['home']! + homeAway['away']! + homeAway['draw']! > 0) ...[
          const SizedBox(height: 24),
          _SectionTitle(title: '🏠 Mandante x Visitante'),
          const SizedBox(height: 8),
          _HomeAwayCard(record: homeAway),
        ],
        if (streak != null) ...[
          const SizedBox(height: 24),
          _SectionTitle(title: '🔥 Sequência de Vitórias'),
          const SizedBox(height: 8),
          _StreakCard(
            teamName: streak['team'] as String,
            streak: streak['streak'] as int,
            competitionId: competition.id,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Melhor Ataque / Melhor Defesa ─────────────────────────────────────────────

class _TeamGoalStatsCard extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String? competitionId;
  final String valueKey;
  final String valueLabel;
  const _TeamGoalStatsCard({
    required this.teams,
    required this.competitionId,
    required this.valueKey,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: teams.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final isLast = i == teams.length - 1;
          final medals = ['🥇', '🥈', '🥉'];

          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: i > 0
                  ? const Border(top: BorderSide(color: Colors.white12))
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(11))
                  : isLast
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(11))
                      : null,
            ),
            child: Row(
              children: [
                SizedBox(
                    width: 26,
                    child: Text(medals[i], style: const TextStyle(fontSize: 16))),
                TeamBadge(
                    teamName: t['team'] as String,
                    competitionId: competitionId,
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(TeamNamesPt.translate(t['team'] as String),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${t[valueKey]} $valueLabel',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Mandante x Visitante ──────────────────────────────────────────────────────

class _HomeAwayCard extends StatelessWidget {
  final Map<String, int> record;
  const _HomeAwayCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final home = record['home']!;
    final away = record['away']!;
    final draw = record['draw']!;
    final total = home + away + draw;
    final homePct = total > 0 ? home / total : 0.0;
    final drawPct = total > 0 ? draw / total : 0.0;
    final awayPct = total > 0 ? away / total : 0.0;

    Widget bar() => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                Expanded(
                    flex: (homePct * 1000).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFF22C55E))),
                Expanded(
                    flex: (drawPct * 1000).round().clamp(1, 1000),
                    child: Container(color: Colors.white24)),
                Expanded(
                    flex: (awayPct * 1000).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFFEF4444))),
              ],
            ),
          ),
        );

    Widget legend(Color color, String label, int pct) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$label $pct%',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              legend(const Color(0xFF22C55E), 'Mandante venceu',
                  (homePct * 100).round()),
              legend(Colors.white24, 'Empate', (drawPct * 100).round()),
              legend(const Color(0xFFEF4444), 'Visitante venceu',
                  (awayPct * 100).round()),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sequência de vitórias ─────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final String teamName;
  final int streak;
  final String? competitionId;
  const _StreakCard(
      {required this.teamName, required this.streak, required this.competitionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          TeamBadge(teamName: teamName, competitionId: competitionId, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(TeamNamesPt.translate(teamName),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
          Text('$streak vitórias seguidas',
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
