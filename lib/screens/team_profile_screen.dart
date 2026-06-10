import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/copa_2026_provider.dart';
import '../providers/history_provider.dart';
import '../models/match.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import '../services/world_cup_api_service.dart';
import 'match_detail_screen.dart';
import 'head_to_head_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamName;
  const TeamProfileScreen({super.key, required this.teamName});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _loadingHistory = true);
    await context.read<HistoryProvider>().loadStatsYears();
    if (mounted) setState(() => _loadingHistory = false);
  }

  @override
  Widget build(BuildContext context) {
    final copa = context.watch<Copa2026Provider>();
    final history = context.watch<HistoryProvider>();
    final team = widget.teamName;
    final flag = TeamFlags.get(team);
    final namePt = TeamNamesPt.translate(team);

    // Copa 2026 matches
    final copa2026Matches = copa.getTeamMatches(team);

    // Estatísticas históricas (de anos já carregados)
    final histStats = _computeHistorical(history, team);

    // Team info from teams list
    final teamInfo = copa.teams.where(
      (t) => t.name == team || t.nameNormalised == team,
    );
    final confed = teamInfo.isNotEmpty ? teamInfo.first.confed : '';
    final group = teamInfo.isNotEmpty ? teamInfo.first.group : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A472A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(namePt,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Confronto Direto',
            icon: const Icon(Icons.compare_arrows,
                color: Color(0xFFFFD700)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    HeadToHeadScreen(initialTeam: team),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A472A), Color(0xFF0D1A0D)],
              ),
            ),
            child: Column(
              children: [
                Text(flag.isNotEmpty ? flag : '🏳️',
                    style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                Text(namePt,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (confed.isNotEmpty) ...[
                      _Chip(confed),
                      const SizedBox(width: 8),
                    ],
                    if (group.isNotEmpty)
                      _Chip('Grupo $group'),
                  ],
                ),
              ],
            ),
          ),

          // Stats da Copa 2026
          if (copa2026Matches.isNotEmpty) ...[
            _SectionHeader(
                icon: Icons.sports_soccer, title: 'Copa 2026 — Jogos'),
            ...copa2026Matches.map((m) => _MatchTile(
                  match: m,
                  teamName: team,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchDetailScreen(
                          match: m, show2026Actions: true),
                    ),
                  ),
                )),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ainda sem jogos na Copa 2026.',
                  style: TextStyle(color: Colors.white38)),
            ),

          // Histórico geral
          _SectionHeader(
              icon: Icons.history, title: 'Histórico nas Copas'),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFFFD700))),
            )
          else
            _HistoryStats(stats: histStats),

          // Botão confronto direto
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HeadToHeadScreen(initialTeam: team),
                ),
              ),
              icon: const Icon(Icons.compare_arrows,
                  color: Color(0xFFFFD700)),
              label: const Text('Confronto Direto',
                  style: TextStyle(color: Color(0xFFFFD700))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color(0xFFFFD700), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _computeHistorical(HistoryProvider h, String team) {
    int copas = 0, wins = 0, draws = 0, losses = 0, gf = 0, ga = 0;
    final yearsPlayed = <int>{};

    for (final year in WorldCupApiService.historicalYears) {
      for (final m in h.getMatches(year)) {
        if (m.team1 != team && m.team2 != team) continue;
        if (m.score?.hasResult != true) continue;
        yearsPlayed.add(year);
        final isHome = m.team1 == team;
        final s1 = isHome ? m.score!.ft[0] : m.score!.ft[1];
        final s2 = isHome ? m.score!.ft[1] : m.score!.ft[0];
        gf += s1;
        ga += s2;
        if (s1 > s2) { wins++; }
        else if (s1 == s2) { draws++; }
        else { losses++; }
      }
    }
    copas = yearsPlayed.length;
    return {
      'copas': copas,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'gf': gf,
      'ga': ga,
      'matches': wins + draws + losses,
    };
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFFFFD700), fontSize: 11)),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Match match;
  final String teamName;
  final VoidCallback onTap;
  const _MatchTile(
      {required this.match,
      required this.teamName,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHome = match.team1 == teamName;
    final opponent = isHome ? match.team2 : match.team1;
    final oppFlag = TeamFlags.get(opponent);
    final oppName = TeamNamesPt.translate(opponent);
    final score = match.score;
    final hasResult = score?.hasResult == true;

    String scoreStr = 'A jogar';
    Color scoreColor = Colors.white38;
    if (hasResult) {
      final s1 = isHome ? score!.ft[0] : score!.ft[1];
      final s2 = isHome ? score!.ft[1] : score!.ft[0];
      scoreStr = '$s1 × $s2';
      scoreColor = s1 > s2
          ? const Color(0xFF4CAF50)
          : s1 < s2
              ? Colors.red.shade400
              : const Color(0xFFFFD700);
    }

    final dt = match.dateTime;
    final dateLabel = DateFormat('dd/MM', 'pt_BR').format(dt);

    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Text(oppFlag.isNotEmpty ? oppFlag : '🏳️',
          style: const TextStyle(fontSize: 26)),
      title: Text(oppName,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Text(dateLabel,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Text(scoreStr,
          style: TextStyle(
              color: scoreColor,
              fontSize: 14,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _HistoryStats extends StatelessWidget {
  final Map<String, int> stats;
  const _HistoryStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats['copas'] == 0) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text('Dados históricos ainda carregando...',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131F13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem('${stats['copas']}', 'Copas'),
              _StatItem('${stats['matches']}', 'Jogos'),
              _StatItem('${stats['wins']}', 'Vitórias'),
              _StatItem('${stats['draws']}', 'Empates'),
              _StatItem('${stats['losses']}', 'Derrotas'),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem('${stats['gf']}', 'Gols pró',
                  color: const Color(0xFF4CAF50)),
              _StatItem('${stats['ga']}', 'Gols contra',
                  color: Colors.red.shade400),
              _StatItem(
                  '${((stats['gf'] ?? 0) - (stats['ga'] ?? 0))}',
                  'Saldo',
                  color: const Color(0xFFFFD700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem(this.value, this.label,
      {this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
