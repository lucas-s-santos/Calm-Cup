import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/copa_2026_provider.dart';
import '../providers/history_provider.dart';
import '../models/match.dart';
import '../services/world_cup_api_service.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import 'match_detail_screen.dart';

class HeadToHeadScreen extends StatefulWidget {
  final String? initialTeam;
  const HeadToHeadScreen({super.key, this.initialTeam});

  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  String? _team1;
  String? _team2;
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _team1 = widget.initialTeam;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    await context.read<HistoryProvider>().loadStatsYears();
    if (mounted) setState(() => _loadingHistory = false);
  }

  List<String> _allTeams(BuildContext context) {
    final copa = context.read<Copa2026Provider>();
    final history = context.read<HistoryProvider>();
    final names = <String>{};
    for (final t in copa.teams) {
      names.add(t.name);
    }
    for (final year in WorldCupApiService.historicalYears) {
      for (final m in history.getMatches(year)) {
        names.add(m.team1);
        names.add(m.team2);
      }
    }
    // também inclui Copa 2026 matches
    for (final m in copa.matches) {
      names.add(m.team1);
      names.add(m.team2);
    }
    final sorted = names.toList()
      ..sort((a, b) => TeamNamesPt.translate(a)
          .compareTo(TeamNamesPt.translate(b)));
    return sorted;
  }

  List<Match> _h2hMatches(BuildContext context) {
    if (_team1 == null || _team2 == null) return [];
    final history = context.read<HistoryProvider>();
    final copa = context.read<Copa2026Provider>();
    final result = <Match>[];

    for (final year in WorldCupApiService.historicalYears) {
      for (final m in history.getMatches(year)) {
        if (_isH2H(m)) result.add(m);
      }
    }
    for (final m in copa.matches) {
      if (_isH2H(m)) result.add(m);
    }
    result.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return result;
  }

  bool _isH2H(Match m) =>
      (m.team1 == _team1 && m.team2 == _team2) ||
      (m.team1 == _team2 && m.team2 == _team1);

  Map<String, int> _computeRecord(List<Match> matches) {
    int w1 = 0, d = 0, w2 = 0, g1 = 0, g2 = 0;
    for (final m in matches) {
      if (m.score?.hasResult != true) continue;
      final s1 = m.team1 == _team1 ? m.score!.ft[0] : m.score!.ft[1];
      final s2 = m.team1 == _team1 ? m.score!.ft[1] : m.score!.ft[0];
      g1 += s1;
      g2 += s2;
      if (s1 > s2) { w1++; }
      else if (s1 == s2) { d++; }
      else { w2++; }
    }
    return {'w1': w1, 'd': d, 'w2': w2, 'g1': g1, 'g2': g2};
  }

  @override
  Widget build(BuildContext context) {
    final teams = _allTeams(context);
    final h2h = _h2hMatches(context);
    final record = _computeRecord(h2h);
    final flag1 = _team1 != null ? TeamFlags.get(_team1!) : '';
    final flag2 = _team2 != null ? TeamFlags.get(_team2!) : '';
    final name1 = _team1 != null ? TeamNamesPt.translate(_team1!) : '—';
    final name2 = _team2 != null ? TeamNamesPt.translate(_team2!) : '—';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A472A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Confronto Direto',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
      body: Column(
        children: [
          // Seletores
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A472A), Color(0xFF0D2A0D)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    child: _TeamPicker(
                  label: name1,
                  flag: flag1,
                  teams: teams,
                  selected: _team1,
                  onSelected: (t) => setState(() => _team1 = t),
                )),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('VS',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                Expanded(
                    child: _TeamPicker(
                  label: name2,
                  flag: flag2,
                  teams: teams,
                  selected: _team2,
                  onSelected: (t) => setState(() => _team2 = t),
                )),
              ],
            ),
          ),

          // Placar do confronto
          if (_team1 != null && _team2 != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: const Color(0xFF131F13),
              child: _loadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFD700)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RecordStat('${record['w1']}',
                            '$flag1 Vitórias', const Color(0xFF4CAF50)),
                        _RecordStat(
                            '${record['d']}', 'Empates', Colors.white54),
                        _RecordStat('${record['w2']}',
                            '$flag2 Vitórias', const Color(0xFFFF6B6B)),
                        _RecordStat(
                            '${record['g1']}×${record['g2']}',
                            'Placar total',
                            const Color(0xFFFFD700)),
                      ],
                    ),
            ),
          ],

          // Lista de jogos
          Expanded(
            child: _team1 == null || _team2 == null
                ? const Center(
                    child: Text(
                        'Selecione duas seleções para ver o histórico.',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center),
                  )
                : _loadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFD700)))
                    : h2h.isEmpty
                        ? const Center(
                            child: Text(
                                'Sem confrontos registrados entre estas seleções.',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13),
                                textAlign: TextAlign.center),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            itemCount: h2h.length,
                            itemBuilder: (ctx, i) {
                              final m = h2h[h2h.length - 1 - i];
                              return _H2HMatchTile(
                                match: m,
                                team1: _team1!,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MatchDetailScreen(match: m),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _TeamPicker extends StatelessWidget {
  final String label;
  final String flag;
  final List<String> teams;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TeamPicker({
    required this.label,
    required this.flag,
    required this.teams,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSearch(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A0D).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected != null
                  ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                  : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down,
                color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TeamSearchSheet(
          teams: teams, onSelected: onSelected),
    );
  }
}

class _TeamSearchSheet extends StatefulWidget {
  final List<String> teams;
  final ValueChanged<String> onSelected;
  const _TeamSearchSheet(
      {required this.teams, required this.onSelected});

  @override
  State<_TeamSearchSheet> createState() => _TeamSearchSheetState();
}

class _TeamSearchSheetState extends State<_TeamSearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.teams
        .where((t) =>
            TeamNamesPt.translate(t)
                .toLowerCase()
                .contains(_q.toLowerCase()) ||
            t.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar seleção...',
                hintStyle:
                    const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0D1A0D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final t = filtered[i];
                final flag = TeamFlags.get(t);
                final name = TeamNamesPt.translate(t);
                return ListTile(
                  leading: Text(flag.isNotEmpty ? flag : '🏳️',
                      style: const TextStyle(fontSize: 22)),
                  title: Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                  onTap: () {
                    widget.onSelected(t);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _RecordStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _H2HMatchTile extends StatelessWidget {
  final Match match;
  final String team1;
  final VoidCallback onTap;
  const _H2HMatchTile(
      {required this.match,
      required this.team1,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isFirst = match.team1 == team1;
    final t1 = isFirst ? match.team1 : match.team2;
    final t2 = isFirst ? match.team2 : match.team1;
    final f1 = TeamFlags.get(t1);
    final f2 = TeamFlags.get(t2);
    final n1 = TeamNamesPt.translate(t1);
    final n2 = TeamNamesPt.translate(t2);

    String scoreStr = '–';
    Color scoreColor = Colors.white38;
    if (match.score?.hasResult == true) {
      final s1 = isFirst ? match.score!.ft[0] : match.score!.ft[1];
      final s2 = isFirst ? match.score!.ft[1] : match.score!.ft[0];
      scoreStr = '$s1 – $s2';
      scoreColor = s1 > s2
          ? const Color(0xFF4CAF50)
          : s1 < s2
              ? const Color(0xFFFF6B6B)
              : Colors.white54;
    }

    final dt = DateTime.tryParse(match.date);
    final year = dt?.year.toString() ?? '';
    final phase = match.group != null
        ? TeamNamesPt.group(match.group!)
        : TeamNamesPt.round(match.round);
    final label = dt != null
        ? DateFormat('dd/MM/yyyy').format(dt)
        : match.date;

    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text('$f1 $n1  ×  $n2 $f2',
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      subtitle: Text('$label  •  $phase',
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(scoreStr,
              style: TextStyle(
                  color: scoreColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          Text(year,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
