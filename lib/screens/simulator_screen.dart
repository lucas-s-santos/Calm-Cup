import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/simulator_provider.dart';
import '../models/match.dart';
import '../models/local_result.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import '../widgets/score_entry_dialog.dart';
import '../widgets/bracket_widget.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimulatorProvider>().load();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SimulatorProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Image.asset(
              'logoCampeonatos_icon.png',
              height: 32,
              errorBuilder: (_, _, _) =>
                  const Text('🎮', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Simulador Copa 2026',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF202020),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) => _handleAction(context, v, provider),
            itemBuilder: (_) => [
              _menuItem('sim_all', Icons.bolt, '⚡ Auto-simular tudo',
                  const Color(0xFFFFD700)),
              _menuItem('sim_groups', Icons.casino, '🎲 Simular grupos',
                  Colors.white70),
              _menuItem('sim_knockout', Icons.emoji_events,
                  '🏆 Simular eliminatórias', Colors.white70),
              const PopupMenuDivider(),
              _menuItem('reset_groups', Icons.undo, '↩ Resetar grupos',
                  Colors.orange),
              _menuItem('reset_all', Icons.delete_outline, '🗑 Resetar tudo',
                  Colors.redAccent),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.group, size: 18), text: 'Grupos'),
            Tab(icon: Icon(Icons.emoji_events, size: 18), text: 'Eliminatórias'),
            Tab(icon: Icon(Icons.account_tree, size: 18), text: 'Bracket'),
          ],
        ),
      ),
      body: provider.loading
          ? const _LoadingView()
          : provider.error != null
              ? _ErrorView(error: provider.error!, onRetry: provider.load)
              : Column(
                  children: [
                    _SimulatorHeader(provider: provider),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _GroupsTab(provider: provider),
                          _KnockoutTab(provider: provider),
                          BracketWidget(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  void _handleAction(
      BuildContext ctx, String action, SimulatorProvider provider) {
    switch (action) {
      case 'sim_all':
        provider.autoSimulateAll();
        _showSnack(ctx, '⚡ Simulação completa!', const Color(0xFFFFD700));
      case 'sim_groups':
        provider.autoSimulateGroups();
        _showSnack(ctx, '🎲 Grupos simulados!', Colors.green);
      case 'sim_knockout':
        if (!provider.allGroupsSimulated) {
          _showSnack(
              ctx, 'Simule os grupos primeiro!', Colors.orange);
          return;
        }
        provider.autoSimulateKnockout();
        _showSnack(ctx, '🏆 Eliminatórias simuladas!', Colors.green);
      case 'reset_groups':
        provider.resetGroups();
        _showSnack(ctx, 'Grupos resetados', Colors.orange);
      case 'reset_all':
        _confirmReset(ctx, provider);
    }
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext ctx, SimulatorProvider provider) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resetar simulação?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Todos os resultados simulados serão apagados.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
    if (ok == true) provider.resetAll();
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFFFD700)),
          SizedBox(height: 16),
          Text('Carregando dados...',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Header / Progress ─────────────────────────────────────────────────────────

class _SimulatorHeader extends StatelessWidget {
  final SimulatorProvider provider;
  const _SimulatorHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final done = provider.simulatedGroupMatches;
    final total = provider.totalGroupMatches;
    final pct = total > 0 ? done / total : 0.0;
    final champion = provider.projectedChampion;
    final championPt = champion != null ? TeamNamesPt.translate(champion) : null;
    final championFlag = champion != null ? TeamFlags.get(champion) : '';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A130A),
        border: Border(
            bottom: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$done / $total',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'jogos de grupos',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: const Color(0xFF202020),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct == 1.0
                          ? Colors.greenAccent
                          : const Color(0xFFFFD700),
                    ),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
          if (champion != null) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A4A1A), Color(0xFF1A3A0A)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Projeção',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9)),
                      Row(
                        children: [
                          if (championFlag.isNotEmpty) ...[
                            Text(championFlag,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            championPt!,
                            style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Groups Tab ────────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final SimulatorProvider provider;
  const _GroupsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Match>>{};
    for (final m in provider.groupMatches) {
      grouped.putIfAbsent(m.group!, () => []).add(m);
    }
    final groups = grouped.keys.toList()..sort();
    final standings = provider.computeAllStandings();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final groupName = groups[i];
        final matches = grouped[groupName]!;
        final groupStandings = standings[groupName] ?? [];
        final letter = groupName.replaceAll('Group ', '');

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Theme(
            data: Theme.of(ctx).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: i == 0,
              iconColor: const Color(0xFFFFD700),
              collapsedIconColor: Colors.white38,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    TeamNamesPt.group(groupName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const Spacer(),
                  if (groupStandings.isNotEmpty)
                    _GroupTopTwo(standings: groupStandings),
                ],
              ),
              children: [
                if (groupStandings.isNotEmpty)
                  _StandingsTable(standings: groupStandings),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text('Partidas',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
                ...matches.map((m) =>
                    _SimMatchRow(match: m, provider: provider)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupTopTwo extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
  const _GroupTopTwo({required this.standings});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: standings.take(2).map((s) {
        final flag = TeamFlags.get(s['team'] as String);
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flag.isNotEmpty) ...[
                Text(flag, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
              ],
              Text(
                TeamNamesPt.translate(s['team'] as String).split(' ').first,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
  const _StandingsTable({required this.standings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: const [
                SizedBox(width: 22),
                SizedBox(width: 8),
                Expanded(
                    child: Text('',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 10))),
                _HCell('PJ'),
                _HCell('V'),
                _HCell('E'),
                _HCell('D'),
                _HCell('SG', width: 32),
                _HCell('PTS', width: 32),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...standings.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final qualified = idx < 2;
            final maybeThird = idx == 2;
            final flag = TeamFlags.get(s['team'] as String);

            return Container(
              decoration: BoxDecoration(
                color: qualified
                    ? const Color(0xFF1E1E1E).withValues(alpha: 0.25)
                    : maybeThird
                        ? const Color(0xFF2A3A1A).withValues(alpha: 0.2)
                        : null,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${idx + 1}',
                        style: TextStyle(
                            color: qualified
                                ? const Color(0xFFFFD700)
                                : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  if (flag.isNotEmpty)
                    Text(flag, style: const TextStyle(fontSize: 15))
                  else
                    const SizedBox(width: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      TeamNamesPt.translate(s['team'] as String),
                      style: TextStyle(
                          color: qualified ? Colors.white : Colors.white60,
                          fontSize: 12,
                          fontWeight: qualified
                              ? FontWeight.w600
                              : FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _DCell('${s['pj']}'),
                  _DCell('${s['v']}'),
                  _DCell('${s['e']}'),
                  _DCell('${s['d']}'),
                  _DCell('${s['sg']}', width: 32),
                  _DCell('${s['pts']}',
                      width: 32,
                      bold: true,
                      color: qualified
                          ? const Color(0xFFFFD700)
                          : Colors.white54),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _HCell extends StatelessWidget {
  final String text;
  final double width;
  const _HCell(this.text, {this.width = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _DCell extends StatelessWidget {
  final String text;
  final double width;
  final bool bold;
  final Color color;

  const _DCell(this.text,
      {this.width = 26,
      this.bold = false,
      this.color = Colors.white54});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

// ── Sim Match Row (group) ─────────────────────────────────────────────────────

class _SimMatchRow extends StatelessWidget {
  final Match match;
  final SimulatorProvider provider;
  const _SimMatchRow({required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    final result = provider.getResult(match.matchKey);
    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);
    final flag1 = TeamFlags.get(match.team1);
    final flag2 = TeamFlags.get(match.team2);
    final hasResult = result != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: hasResult
            ? const Color(0xFF162916)
            : const Color(0xFF111A11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasResult
              ? const Color(0xFFFFD700).withValues(alpha: 0.2)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      name1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: hasResult && result[0] > result[1]
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: hasResult && result[0] > result[1]
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (flag1.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(flag1, style: const TextStyle(fontSize: 17)),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _openDialog(context),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 5),
                decoration: BoxDecoration(
                  color: hasResult
                      ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                      : const Color(0xFF1E2E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasResult
                        ? const Color(0xFFFFD700).withValues(alpha: 0.35)
                        : Colors.white12,
                  ),
                ),
                child: Text(
                  hasResult
                      ? '${result[0]}  ×  ${result[1]}'
                      : '—  ×  —',
                  style: TextStyle(
                      color: hasResult
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (flag2.isNotEmpty) ...[
                    Text(flag2, style: const TextStyle(fontSize: 17)),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      name2,
                      style: TextStyle(
                        color: hasResult && result[1] > result[0]
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: hasResult && result[1] > result[0]
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                final score =
                    provider.autoSimulateKnockoutMatch(canDraw: true);
                provider.setResult(match, score[0], score[1]);
              },
              icon: const Icon(Icons.casino_outlined,
                  color: Colors.white38, size: 17),
              tooltip: 'Sortear resultado',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final result = provider.getResult(match.matchKey);
    final existing = result != null
        ? LocalResult(
            matchKey: match.matchKey,
            score1: result[0],
            score2: result[1])
        : null;
    final dialogResult = await showDialog(
      context: context,
      builder: (_) =>
          ScoreEntryDialog(match: match, existingResult: existing),
    );
    if (dialogResult == 'delete') {
      provider.removeResult(match.matchKey);
    } else if (dialogResult is List<int> && dialogResult.length == 2) {
      provider.setResult(match, dialogResult[0], dialogResult[1]);
    }
  }
}

// ── Knockout Tab ──────────────────────────────────────────────────────────────

class _KnockoutTab extends StatelessWidget {
  final SimulatorProvider provider;
  const _KnockoutTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.allGroupsSimulated) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⚽', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Simule a fase de grupos primeiro',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'para ver as eliminatórias',
                style: TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<SimulatorProvider>().autoSimulateGroups(),
                icon: const Icon(Icons.bolt),
                label: const Text('Auto-simular grupos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    provider.reset3rdAssignment();

    final rounds = [
      (TeamNamesPt.round('Round of 32'), provider.roundOf32),
      (TeamNamesPt.round('Round of 16'), provider.roundOf16),
      (TeamNamesPt.round('Quarter-final'), provider.quarterFinals),
      (TeamNamesPt.round('Semi-final'), provider.semiFinals),
      (TeamNamesPt.round('Match for third place'), provider.thirdPlace),
      (TeamNamesPt.round('Final'), provider.final_),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        for (final (label, matches) in rounds)
          if (matches.isNotEmpty) ...[
            _RoundHeader(label: label),
            for (final m in matches)
              _KnockoutCard(match: m, provider: provider),
          ],
      ],
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final String label;
  const _RoundHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isFinal = label == 'Final';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: isFinal
            ? const LinearGradient(
                colors: [Color(0xFF3A2A00), Color(0xFF2A1A00)],
              )
            : const LinearGradient(
                colors: [Color(0xFF262626), Color(0xFF121212)],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFinal
              ? const Color(0xFFFFD700).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          if (isFinal)
            const Text('🏆', style: TextStyle(fontSize: 16))
          else
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
                color: isFinal
                    ? const Color(0xFFFFD700)
                    : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _KnockoutCard extends StatelessWidget {
  final Match match;
  final SimulatorProvider provider;
  const _KnockoutCard({required this.match, required this.provider});

  @override
  Widget build(BuildContext context) {
    final t1 = provider.resolveCode(match.team1);
    final t2 = provider.resolveCode(match.team2);
    final result = provider.getResult(match.matchKey);
    final tbd1 = t1 == match.team1 && match.team1.length > 2;
    final tbd2 = t2 == match.team2 && match.team2.length > 2;
    final pt1 = tbd1 ? '' : TeamNamesPt.translate(t1);
    final pt2 = tbd2 ? '' : TeamNamesPt.translate(t2);
    final flag1 = tbd1 ? '' : TeamFlags.get(t1);
    final flag2 = tbd2 ? '' : TeamFlags.get(t2);
    final hasResult = result != null;
    final isFinal = match.round == 'Final';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: isFinal
            ? const Color(0xFF1E1A00)
            : const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFinal
              ? const Color(0xFFFFD700).withValues(alpha: 0.4)
              : hasResult
                  ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                  : Colors.white12,
          width: isFinal ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text(TeamNamesPt.round(match.round),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.location_on,
                    color: Colors.white24, size: 11),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    match.ground,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _KnockoutTeam(
                    name: tbd1 ? 'A definir' : pt1,
                    flag: flag1,
                    tbd: tbd1,
                    align: TextAlign.right,
                    isWinner: hasResult && result[0] > result[1],
                  ),
                ),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: hasResult
                        ? const Color(0xFFFFD700)
                            .withValues(alpha: 0.12)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasResult
                          ? const Color(0xFFFFD700)
                              .withValues(alpha: 0.35)
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    hasResult
                        ? '${result[0]}  ×  ${result[1]}'
                        : 'x',
                    style: TextStyle(
                      color: hasResult
                          ? const Color(0xFFFFD700)
                          : Colors.white24,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: _KnockoutTeam(
                    name: tbd2 ? 'A definir' : pt2,
                    flag: flag2,
                    tbd: tbd2,
                    align: TextAlign.left,
                    isWinner: hasResult && result[1] > result[0],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!tbd1 && !tbd2)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.casino_outlined,
                    label: 'Auto',
                    onTap: () {
                      final score = provider
                          .autoSimulateKnockoutMatch(canDraw: false);
                      provider.setResult(match, score[0], score[1]);
                    },
                    gold: false,
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Inserir placar',
                    onTap: () => _openDialog(context, t1, t2),
                    gold: true,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog(
      BuildContext context, String t1, String t2) async {
    final fakeMatch = Match(
      round: match.round,
      date: match.date,
      time: match.time,
      team1: t1,
      team2: t2,
      ground: match.ground,
      num: match.num,
    );
    final existing = provider.getResult(match.matchKey);
    final existingResult = existing != null
        ? LocalResult(
            matchKey: match.matchKey,
            score1: existing[0],
            score2: existing[1])
        : null;
    final result = await showDialog(
      context: context,
      builder: (_) =>
          ScoreEntryDialog(match: fakeMatch, existingResult: existingResult),
    );
    if (result == 'delete') {
      provider.removeResult(match.matchKey);
    } else if (result is List<int> && result.length == 2) {
      provider.setResult(match, result[0], result[1]);
    }
  }
}

class _KnockoutTeam extends StatelessWidget {
  final String name;
  final String flag;
  final bool tbd;
  final TextAlign align;
  final bool isWinner;

  const _KnockoutTeam({
    required this.name,
    required this.flag,
    required this.tbd,
    required this.align,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final nameWidget = Text(
      name,
      textAlign: align,
      style: TextStyle(
        color: tbd
            ? Colors.white24
            : isWinner
                ? Colors.white
                : Colors.white70,
        fontSize: 13,
        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
        fontStyle: tbd ? FontStyle.italic : FontStyle.normal,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final flagWidget = flag.isNotEmpty
        ? Text(flag, style: const TextStyle(fontSize: 22))
        : const SizedBox.shrink();

    if (align == TextAlign.right) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(child: nameWidget),
          if (flag.isNotEmpty) ...[
            const SizedBox(width: 8),
            flagWidget,
          ],
        ],
      );
    }
    return Row(
      children: [
        if (flag.isNotEmpty) ...[
          flagWidget,
          const SizedBox(width: 8),
        ],
        Flexible(child: nameWidget),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gold;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: gold ? const Color(0xFFFFD700) : Colors.white54,
        side: BorderSide(
          color: gold
              ? const Color(0xFFFFD700).withValues(alpha: 0.6)
              : Colors.white24,
          width: 0.8,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off,
                  color: Colors.white38, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Erro ao carregar dados',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
