import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../models/local_result.dart';
import '../models/stadium.dart';
import '../providers/copa_2026_provider.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import '../widgets/score_entry_dialog.dart';

class MatchDetailScreen extends StatelessWidget {
  final Match match;
  final bool show2026Actions;

  const MatchDetailScreen({
    super.key,
    required this.match,
    this.show2026Actions = false,
  });

  @override
  Widget build(BuildContext context) {
    LocalResult? localResult;
    Stadium? stadium;
    if (show2026Actions) {
      final prov = context.watch<Copa2026Provider>();
      localResult = prov.localResults[match.matchKey];
      stadium = prov.getStadium(match.ground);
    }

    final apiScore = match.score;
    final hasApiResult = apiScore?.hasResult == true;
    final hasLocalResult = localResult != null;

    String scoreText = 'A jogar';
    bool isLocal = false;
    if (hasApiResult) {
      scoreText = apiScore!.displayScore;
    } else if (hasLocalResult) {
      scoreText = localResult.displayScore;
      isLocal = true;
    }

    final dateFormatted = _formatDate(match.date);
    final roundLabel = match.round.startsWith('Group')
        ? TeamNamesPt.group(match.round)
        : TeamNamesPt.round(match.round);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A472A),
        title: Text(roundLabel,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Cabeçalho com placar
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A472A), Color(0xFF0D1A0D)],
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  if (match.group != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(TeamNamesPt.group(match.group!),
                          style: const TextStyle(
                              color: Color(0xFFFFD700), fontSize: 13)),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TeamColumn(name: match.team1),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: (hasApiResult || hasLocalResult)
                                  ? const Color(0xFFFFD700)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFF1E2D1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isLocal
                                    ? const Color(0xFFFFD700)
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              scoreText,
                              style: TextStyle(
                                color: (hasApiResult || hasLocalResult)
                                    ? const Color(0xFFFFD700)
                                    : Colors.white38,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isLocal) ...[
                            const SizedBox(height: 6),
                            const Text('📝 Resultado local',
                                style: TextStyle(
                                    color: Color(0xFFFFD700), fontSize: 11)),
                          ],
                          if (apiScore?.ht != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Intervalo: ${apiScore!.ht![0]}-${apiScore.ht![1]}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                          if (apiScore?.et != null) ...[
                            Text(
                              'Prorrogação: ${apiScore!.et![0]}-${apiScore.et![1]}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                          if (apiScore?.p != null) ...[
                            Text(
                              'Pênaltis: ${apiScore!.p![0]}-${apiScore.p![1]}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      _TeamColumn(name: match.team2),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(dateFormatted,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time,
                          color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(match.time,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(match.ground,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                  if (stadium != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(stadium.countryFlag,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          stadium.name,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        const Text('  •  ',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 11)),
                        const Icon(Icons.people,
                            color: Colors.white38, size: 11),
                        const SizedBox(width: 3),
                        Text(
                          _fmtCapacity(stadium.capacity),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Botão de inserir resultado (Copa 2026)
            if (show2026Actions && !hasApiResult)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openScoreDialog(context, localResult),
                    icon: const Icon(Icons.edit),
                    label: Text(hasLocalResult
                        ? 'Editar resultado'
                        : 'Inserir resultado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

            // Timeline de gols
            if (match.goals1.isNotEmpty || match.goals2.isNotEmpty) ...[
              const _SectionDivider(title: 'Linha do Tempo'),
              _GoalTimeline(match: match),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _fmtCapacity(int n) {
    if (n >= 1000) return '${(n / 1000).round()}k';
    return n.toString();
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat("dd 'de' MMMM 'de' yyyy", 'pt_BR').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _openScoreDialog(
      BuildContext context, LocalResult? existing) async {
    final provider = context.read<Copa2026Provider>();
    final result = await showDialog(
      context: context,
      builder: (_) => ScoreEntryDialog(match: match, existingResult: existing),
    );
    if (result == 'delete') {
      await provider.deleteResult(match.matchKey);
    } else if (result is List<int> && result.length == 2) {
      await provider.saveResult(match.matchKey, result[0], result[1]);
    }
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  const _TeamColumn({required this.name});

  @override
  Widget build(BuildContext context) {
    final flag = TeamFlags.get(name);
    final namePt = TeamNamesPt.translate(name);

    return SizedBox(
      width: 90,
      child: Column(
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
          ],
          Text(
            namePt,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GoalTimeline extends StatelessWidget {
  final Match match;
  const _GoalTimeline({required this.match});

  @override
  Widget build(BuildContext context) {
    // Junta todos os gols com o lado (1 = time da esquerda, 2 = direita)
    final all = [
      ...match.goals1.map((g) => (goal: g, side: 1)),
      ...match.goals2.map((g) => (goal: g, side: 2)),
    ]..sort((a, b) => a.goal.minute.compareTo(b.goal.minute));

    final isKnockout = match.group == null;
    final maxMin = isKnockout ? 120 : 90;
    final flag1 = TeamFlags.get(match.team1);
    final flag2 = TeamFlags.get(match.team2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Barra visual da linha do tempo
          LayoutBuilder(builder: (_, box) {
            final w = box.maxWidth;
            return SizedBox(
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Trilho de fundo
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Divisor do intervalo (45')
                  Positioned(
                    top: 8,
                    left: (45 / maxMin) * w - 1,
                    child: Container(
                        width: 2, height: 20, color: Colors.white24),
                  ),
                  // Marcadores de gol
                  ...all.map((e) {
                    final min =
                        e.goal.minute + (e.goal.offset ?? 0) * 0.5;
                    final x =
                        ((min.clamp(0, maxMin.toDouble()) / maxMin) *
                                w)
                            .clamp(0.0, w - 16.0);
                    final color = e.side == 1
                        ? const Color(0xFFFFD700)
                        : Colors.lightBlueAccent;
                    return Positioned(
                      left: x,
                      top: 0,
                      child: Column(
                        children: [
                          Icon(
                            e.goal.ownGoal
                                ? Icons.sports_soccer
                                : Icons.sports_soccer,
                            size: 18,
                            color: e.goal.ownGoal
                                ? Colors.red.shade400
                                : color,
                          ),
                          Container(
                              width: 2, height: 16, color: color),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Legenda dos minutos
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("0'",
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
                Text("45'",
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
                Text("$maxMin'",
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Lista cronológica dos gols
          ...all.map((e) {
            final g = e.goal;
            final teamFlag =
                e.side == 1 ? flag1 : flag2;
            final color = e.side == 1
                ? const Color(0xFFFFD700)
                : Colors.lightBlueAccent;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      g.displayMinute,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(g.icon,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Text(teamFlag,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String title;
  const _SectionDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const Expanded(child: Divider(color: Colors.white12)),
        ],
      ),
    );
  }
}
