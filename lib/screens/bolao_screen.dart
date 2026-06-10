import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/copa_2026_provider.dart';
import '../providers/bolao_provider.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';

class BolaoScreen extends StatefulWidget {
  const BolaoScreen({super.key});

  @override
  State<BolaoScreen> createState() => _BolaoScreenState();
}

class _BolaoScreenState extends State<BolaoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final matches = context.read<Copa2026Provider>().matches;
    if (matches.isNotEmpty) {
      context.read<BolaoProvider>().load(matches);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copa = context.watch<Copa2026Provider>();
    final bolao = context.watch<BolaoProvider>();
    final total = bolao.computeTotal(copa.matches);
    final predCount = bolao.predictions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A472A),
        title: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Bolão Copa 2026',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Apostar'),
            Tab(text: 'Meus Palpites'),
          ],
        ),
      ),
      body: copa.loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : Column(
              children: [
                // Banner de pontuação
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A472A), Color(0xFF0D2A0D)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$total pontos',
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$predCount palpite${predCount != 1 ? 's' : ''} feito${predCount != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Sistema de pontos',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                          const SizedBox(height: 2),
                          _pointChip('⚽ Exato', '3 pts'),
                          _pointChip('✅ Resultado', '1 pt'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ApostarTab(matches: copa.matches),
                      _MeusPalpitesTab(matches: copa.matches),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pointChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Tab Apostar ───────────────────────────────────────────────────────────────

class _ApostarTab extends StatelessWidget {
  final List<Match> matches;
  const _ApostarTab({required this.matches});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = matches.where((m) => m.dateTime.isAfter(now)).toList();

    if (upcoming.isEmpty) {
      return const Center(
        child: Text('Nenhum jogo futuro para apostar.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final grouped = <String, List<Match>>{};
    for (final m in upcoming) {
      grouped.putIfAbsent(m.date, () => []).add(m);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: dates.length,
      itemBuilder: (ctx, i) {
        final date = dates[i];
        final dayMatches = grouped[date]!;
        final dt = DateTime.tryParse(date);
        final label = dt != null
            ? DateFormat("EEE, dd 'de' MMMM", 'pt_BR').format(dt)
            : date;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(label: label),
            ...dayMatches.map((m) => _PredictionCard(match: m)),
          ],
        );
      },
    );
  }
}

// ── Tab Meus Palpites ─────────────────────────────────────────────────────────

class _MeusPalpitesTab extends StatelessWidget {
  final List<Match> matches;
  const _MeusPalpitesTab({required this.matches});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    if (!bolao.loaded) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    final myMatches = matches
        .where((m) => bolao.predictions.containsKey(m.matchKey))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (myMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🎯', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Nenhum palpite ainda.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Vá na aba "Apostar" e faça seus palpites!',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: myMatches.length,
      itemBuilder: (ctx, i) => _ResultCard(match: myMatches[i]),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Match match;
  const _PredictionCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    final pred = bolao.predictions[match.matchKey];
    final flag1 = TeamFlags.get(match.team1);
    final flag2 = TeamFlags.get(match.team2);
    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);
    final phase = match.group != null
        ? TeamNamesPt.group(match.group!)
        : TeamNamesPt.round(match.round);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131F13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pred != null
              ? const Color(0xFFFFD700).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(phase,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('$flag1 $name1',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              if (pred != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                  ),
                  child: Text(pred.displayScore,
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(' ? × ? ',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              Expanded(
                child: Text('$name2 $flag2',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pred != null)
                TextButton.icon(
                  onPressed: () =>
                      _openDialog(context, existing: pred),
                  icon: const Icon(Icons.edit, size: 14,
                      color: Colors.white54),
                  label: const Text('Alterar',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 12)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _openDialog(context, existing: pred),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child:
                    Text(pred != null ? 'Meu palpite' : 'Apostar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDialog(BuildContext context,
      {Prediction? existing}) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _PredictionDialog(
        match: match,
        initial1: existing?.score1 ?? 0,
        initial2: existing?.score2 ?? 0,
      ),
    );
    if (result != null && context.mounted) {
      await context
          .read<BolaoProvider>()
          .savePrediction(match, result[0], result[1]);
    }
  }
}

class _ResultCard extends StatelessWidget {
  final Match match;
  const _ResultCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    final pred = bolao.predictions[match.matchKey]!;
    final score = match.score;
    final hasResult = score?.hasResult == true;

    final pts = hasResult
        ? pred.calculatePoints(score!.ft[0], score.ft[1])
        : -1;

    final flag1 = TeamFlags.get(match.team1);
    final flag2 = TeamFlags.get(match.team2);
    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);

    Color ptColor;
    String ptLabel;
    if (pts == 3) {
      ptColor = const Color(0xFF4CAF50);
      ptLabel = '+3';
    } else if (pts == 1) {
      ptColor = const Color(0xFFFFD700);
      ptLabel = '+1';
    } else if (pts == 0) {
      ptColor = Colors.red.shade400;
      ptLabel = '+0';
    } else {
      ptColor = Colors.white38;
      ptLabel = '–';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131F13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pts == 3
                ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                : pts == 1
                    ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                    : Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$flag1 $name1 × $name2 $flag2',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ScoreBox(
                        label: 'Meu palpite', score: pred.displayScore),
                    const SizedBox(width: 12),
                    if (hasResult)
                      _ScoreBox(
                          label: 'Resultado',
                          score: '${score!.ft[0]} × ${score.ft[1]}',
                          highlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ptColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: ptColor.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Text(ptLabel,
                  style: TextStyle(
                      color: ptColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String score;
  final bool highlight;
  const _ScoreBox(
      {required this.label, required this.score, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(score,
            style: TextStyle(
                color: highlight
                    ? const Color(0xFFFFD700)
                    : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Diálogo de palpite ────────────────────────────────────────────────────────

class _PredictionDialog extends StatefulWidget {
  final Match match;
  final int initial1;
  final int initial2;
  const _PredictionDialog(
      {required this.match, required this.initial1, required this.initial2});

  @override
  State<_PredictionDialog> createState() => _PredictionDialogState();
}

class _PredictionDialogState extends State<_PredictionDialog> {
  late int _s1;
  late int _s2;

  @override
  void initState() {
    super.initState();
    _s1 = widget.initial1;
    _s2 = widget.initial2;
  }

  @override
  Widget build(BuildContext context) {
    final flag1 = TeamFlags.get(widget.match.team1);
    final flag2 = TeamFlags.get(widget.match.team2);
    final name1 = TeamNamesPt.translate(widget.match.team1);
    final name2 = TeamNamesPt.translate(widget.match.team2);

    return AlertDialog(
      backgroundColor: const Color(0xFF1A2A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Meu Palpite 🎯',
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$flag1 $name1  ×  $name2 $flag2',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScoreSpinner(
                  value: _s1,
                  onChanged: (v) => setState(() => _s1 = v)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('×',
                    style: TextStyle(color: Colors.white54, fontSize: 22)),
              ),
              _ScoreSpinner(
                  value: _s2,
                  onChanged: (v) => setState(() => _s2 = v)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, [_s1, _s2]),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black),
          child: const Text('Confirmar',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ScoreSpinner extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _ScoreSpinner({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline,
              color: Color(0xFFFFD700), size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(height: 4),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1A0D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: Icon(Icons.remove_circle_outline,
              color: value > 0
                  ? const Color(0xFFFFD700)
                  : Colors.white24,
              size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
