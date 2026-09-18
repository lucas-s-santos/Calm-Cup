import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../providers/copa_2026_provider.dart';
import '../providers/competition_provider.dart';
import '../providers/bolao_provider.dart';
import '../providers/ranking_provider.dart';
import '../models/match.dart';
import '../models/prediction.dart';
import '../models/ranking_entry.dart';
import '../utils/team_names_pt.dart';
import '../widgets/team_badge.dart';

class BolaoScreen extends StatefulWidget {
  const BolaoScreen({super.key});

  @override
  State<BolaoScreen> createState() => _BolaoScreenState();
}

class _BolaoScreenState extends State<BolaoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabs;

  // null = Copa do Mundo 2026 (padrão, com seu próprio provider dedicado);
  // qualquer outro valor usa um CompetitionProvider genérico, criado sob
  // demanda e mantido em cache pra não refazer o fetch ao alternar de volta.
  Competition? _selected;
  final Map<String, CompetitionProvider> _providers = {};

  String get _rankingCompetitionId => _selected?.id ?? 'copa-2026';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    for (final p in _providers.values) {
      p.dispose();
    }
    super.dispose();
  }

  // Ranking (Firebase) só é acordado quando a 3ª aba é de fato aberta — nunca
  // no boot do app nem só por visitar o Bolão. `init()`/`watchCompetition`
  // são idempotentes, então disparar isso mais de uma vez durante o arraste
  // de troca de aba (o TabController notifica o listener várias vezes numa
  // única transição) não causa chamadas duplicadas de verdade.
  void _onTabChanged() {
    if (_tabs.index != 2) return;
    final ranking = context.read<RankingProvider>();
    ranking.init().then((_) {
      if (mounted) ranking.watchCompetition(_rankingCompetitionId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final ranking = context.read<RankingProvider>();
      // Só reconsulta se a pessoa já tinha aberto o Ranking antes — evita
      // acordar o Firebase por causa de um resume qualquer do app.
      if (ranking.initialized) {
        ranking.watchCompetition(_rankingCompetitionId);
      }
    }
  }

  CompetitionProvider _providerFor(Competition c) =>
      _providers.putIfAbsent(c.id, () => CompetitionProvider(c));

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected == null) {
      final copa = context.watch<Copa2026Provider>();
      if (copa.matches.isNotEmpty) {
        context.read<BolaoProvider>().load(copa.matches);
      }
      return _buildScaffold(
        title: 'Bolão Copa 2026',
        matches: copa.matches,
        loading: copa.loading,
        competitionId: null,
        editionId: '2026',
      );
    }

    final provider = _providerFor(selected);
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.matches.isNotEmpty) {
          context.read<BolaoProvider>().load(provider.matches);
        }
        return _buildScaffold(
          title: 'Bolão · ${selected.name}',
          matches: provider.matches,
          loading: provider.loading,
          competitionId: selected.id,
          editionId: provider.edition.id,
        );
      },
    );
  }

  Widget _buildScaffold({
    required String title,
    required List<Match> matches,
    required bool loading,
    required String? competitionId,
    required String editionId,
  }) {
    final bolao = context.watch<BolaoProvider>();
    final total = bolao.computeTotal(matches);
    final predCount =
        matches.where((m) => bolao.predictions.containsKey(m.matchKey)).length;
    // Sincroniza o total já calculado localmente pro Firestore — barato de
    // chamar em todo build, igual `BolaoProvider.load()` já é hoje: o
    // próprio `RankingProvider` decide internamente se há algo novo pra
    // enviar (idempotente, e não faz nada até a pessoa abrir a aba Ranking
    // pela 1ª vez e escolher um apelido).
    context
        .read<RankingProvider>()
        .syncIfChanged(_rankingCompetitionId, editionId, total, predCount);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<Competition?>(
            tooltip: 'Trocar campeonato',
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            onSelected: (c) => setState(() => _selected = c),
            itemBuilder: (context) => [
              const PopupMenuItem<Competition?>(
                value: null,
                child: Text('🏆 Copa do Mundo 2026'),
              ),
              const PopupMenuDivider(),
              ...competitionsCatalog.map((c) => PopupMenuItem<Competition?>(
                    value: c,
                    child: Text('${c.emoji} ${c.name}'),
                  )),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFFFD700),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Apostar'),
            Tab(text: 'Meus Palpites'),
            Tab(text: 'Ranking'),
          ],
        ),
      ),
      body: loading
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
                      colors: [Color(0xFF1E1E1E), Color(0xFF0D2A0D)],
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
                      _ApostarTab(matches: matches, competitionId: competitionId),
                      _MeusPalpitesTab(
                          matches: matches, competitionId: competitionId),
                      _RankingTab(competitionId: _rankingCompetitionId),
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
  final String? competitionId;
  const _ApostarTab({required this.matches, this.competitionId});

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
            ...dayMatches.map((m) =>
                _PredictionCard(match: m, competitionId: competitionId)),
          ],
        );
      },
    );
  }
}

// ── Tab Meus Palpites ─────────────────────────────────────────────────────────

class _MeusPalpitesTab extends StatelessWidget {
  final List<Match> matches;
  final String? competitionId;
  const _MeusPalpitesTab({required this.matches, this.competitionId});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    if (!bolao.isLoaded(matches)) {
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
      itemBuilder: (ctx, i) =>
          _ResultCard(match: myMatches[i], competitionId: competitionId),
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
  final String? competitionId;
  const _PredictionCard({required this.match, this.competitionId});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    final pred = bolao.predictions[match.matchKey];
    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);
    final phase = match.group != null
        ? TeamNamesPt.group(match.group!)
        : TeamNamesPt.round(match.round);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
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
                child: Row(
                  children: [
                    TeamBadge(
                        teamName: match.team1,
                        competitionId: competitionId,
                        size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(name1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(name2,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    TeamBadge(
                        teamName: match.team2,
                        competitionId: competitionId,
                        size: 18),
                  ],
                ),
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
        competitionId: competitionId,
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
  final String? competitionId;
  const _ResultCard({required this.match, this.competitionId});

  @override
  Widget build(BuildContext context) {
    final bolao = context.watch<BolaoProvider>();
    final pred = bolao.predictions[match.matchKey]!;
    final score = match.score;
    final hasResult = score?.hasResult == true;

    final pts = hasResult
        ? pred.calculatePoints(score!.ft[0], score.ft[1])
        : -1;

    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);

    Color ptColor;
    String ptLabel;
    if (pts == 3) {
      ptColor = const Color(0xFF22C55E);
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
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pts == 3
                ? const Color(0xFF22C55E).withValues(alpha: 0.4)
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
                Row(
                  children: [
                    TeamBadge(
                        teamName: match.team1,
                        competitionId: competitionId,
                        size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('$name1 × $name2',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    TeamBadge(
                        teamName: match.team2,
                        competitionId: competitionId,
                        size: 16),
                  ],
                ),
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
  final String? competitionId;
  final int initial1;
  final int initial2;
  const _PredictionDialog(
      {required this.match,
      this.competitionId,
      required this.initial1,
      required this.initial2});

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
    final name1 = TeamNamesPt.translate(widget.match.team1);
    final name2 = TeamNamesPt.translate(widget.match.team2);

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Meu Palpite 🎯',
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TeamBadge(
                  teamName: widget.match.team1,
                  competitionId: widget.competitionId,
                  size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$name1  ×  $name2',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 6),
              TeamBadge(
                  teamName: widget.match.team2,
                  competitionId: widget.competitionId,
                  size: 18),
            ],
          ),
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
            color: const Color(0xFF121212),
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

// ── Tab Ranking (Firebase) ───────────────────────────────────────────────────

class _RankingTab extends StatelessWidget {
  final String competitionId;
  const _RankingTab({required this.competitionId});

  @override
  Widget build(BuildContext context) {
    final ranking = context.watch<RankingProvider>();

    if (ranking.unavailable) {
      return const _RankingMessage(
        emoji: '📡',
        title: 'Ranking indisponível',
        subtitle:
            'Não foi possível conectar ao ranking online agora. Seus palpites '
            'continuam salvos normalmente neste aparelho.',
      );
    }

    if (!ranking.initialized ||
        (ranking.loadingRanking && ranking.topEntries(competitionId).isEmpty)) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    final entries = ranking.topEntries(competitionId);

    return Column(
      children: [
        _NicknameBanner(ranking: ranking),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ninguém no ranking deste campeonato ainda.\nFaça seus palpites e seja o primeiro!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) => _RankingRow(
                    position: i + 1,
                    entry: entries[i],
                    isMe: entries[i].uid == ranking.myUid,
                  ),
                ),
        ),
      ],
    );
  }
}

class _RankingMessage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _RankingMessage(
      {required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _NicknameBanner extends StatelessWidget {
  final RankingProvider ranking;
  const _NicknameBanner({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final hasNickname = ranking.hasNickname;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          if (hasNickname) ...[
            _RankInitialsAvatar(name: ranking.nickname!, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Você está apostando como',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(ranking.nickname!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openNicknameDialog(context),
              child: const Text('Trocar',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
            ),
          ] else ...[
            const Expanded(
              child: Text(
                'Escolha um apelido pra entrar no ranking 🏅',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            ElevatedButton(
              onPressed: () => _openNicknameDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
              child: const Text('Definir'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openNicknameDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NicknameDialog(initial: ranking.nickname ?? ''),
    );
    if (result != null && result.trim().isNotEmpty) {
      await ranking.setNickname(result.trim());
    }
  }
}

class _RankInitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _RankInitialsAvatar({required this.name, this.size = 32});

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
    Color(0xFF4F46E5),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _palette[name.hashCode.abs() % _palette.length],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9]'), '');
    if (letters.isEmpty) return '?';
    return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _RankingRow extends StatelessWidget {
  final int position;
  final RankingEntry entry;
  final bool isMe;
  const _RankingRow(
      {required this.position, required this.entry, required this.isMe});

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final medal = _medals[position];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFFFFD700).withValues(alpha: 0.08)
            : const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 18))
                : Text('$position',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          _RankInitialsAvatar(name: entry.nickname, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(entry.nickname,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight:
                                  isMe ? FontWeight.bold : FontWeight.w600)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Text('(você)',
                          style: TextStyle(
                              color: Color(0xFFFFD700), fontSize: 11)),
                    ],
                  ],
                ),
                Text(
                    '${entry.predictionsMade} palpite${entry.predictionsMade != 1 ? 's' : ''}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Text('${entry.points} pts',
              style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _NicknameDialog extends StatefulWidget {
  final String initial;
  const _NicknameDialog({required this.initial});

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Seu apelido no ranking 🏅',
          style: TextStyle(color: Color(0xFFFFD700), fontSize: 16)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Ex: CraqueDoBolão',
          hintStyle: TextStyle(color: Colors.white24),
          counterStyle: TextStyle(color: Colors.white24),
          enabledBorder:
              UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFFD700))),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
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
