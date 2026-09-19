import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/competition.dart';
import '../models/match.dart';
import '../providers/competition_provider.dart';
import '../theme/app_colors.dart';
import '../utils/team_names_pt.dart';
import '../widgets/match_card.dart';
import '../widgets/offline_banner.dart';
import '../widgets/standings_table.dart';
import 'match_detail_screen.dart';

/// Tela genérica pra qualquer competição do catálogo (Eurocopa, ligas
/// europeias, Champions League...) — duas abas: "Jogos" (lista por rodada)
/// e "Classificação"/"Grupos" dependendo do formato. A Copa 2026 continua
/// com sua própria tela (`Copa2026Screen`), não passa por aqui.
class CompetitionScreen extends StatelessWidget {
  final Competition competition;
  const CompetitionScreen({super.key, required this.competition});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompetitionProvider(competition),
      child: _CompetitionView(competition: competition),
    );
  }
}

class _CompetitionView extends StatefulWidget {
  final Competition competition;
  const _CompetitionView({required this.competition});

  @override
  State<_CompetitionView> createState() => _CompetitionViewState();
}

class _CompetitionViewState extends State<_CompetitionView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CompetitionProvider>();
    final isLeague = widget.competition.format == CompetitionFormat.league;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: Row(
          children: [
            Text(widget.competition.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.competition.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.competition.editions.length > 1)
            PopupMenuButton<CompetitionEdition>(
              onSelected: (e) => context.read<CompetitionProvider>().selectEdition(e),
              itemBuilder: (_) => widget.competition.editions
                  .map((e) => PopupMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(provider.edition.label,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const Icon(Icons.arrow_drop_down, color: AppColors.gold),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(provider.edition.label,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          indicatorWeight: 3,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            const Tab(text: 'Jogos'),
            Tab(text: isLeague ? 'Classificação' : 'Grupos'),
          ],
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : provider.error != null
              ? _ErrorState(onRetry: provider.load)
              : Column(
                  children: [
                    if (provider.fromCache) const OfflineBanner(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _FixturesTab(provider: provider),
                          isLeague
                              ? _LeagueTableTab(provider: provider)
                              : _GroupsTab(provider: provider),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Aba Jogos ────────────────────────────────────────────────────────────────

class _FixturesTab extends StatefulWidget {
  final CompetitionProvider provider;
  const _FixturesTab({required this.provider});

  @override
  State<_FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends State<_FixturesTab> {
  String _query = '';
  String? _selectedRound;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final allRounds = provider.roundsSorted;
    if (allRounds.isEmpty) {
      return const Center(
        child: Text('Nenhum jogo encontrado',
            style: TextStyle(color: Colors.white54)),
      );
    }

    final query = _query.trim().toLowerCase();
    bool matchesQuery(Match m) {
      if (query.isEmpty) return true;
      return TeamNamesPt.translate(m.team1).toLowerCase().contains(query) ||
          TeamNamesPt.translate(m.team2).toLowerCase().contains(query) ||
          m.team1.toLowerCase().contains(query) ||
          m.team2.toLowerCase().contains(query);
    }

    final visibleRounds = allRounds
        .where((entry) => _selectedRound == null || entry.key == _selectedRound)
        .map((entry) =>
            MapEntry(entry.key, entry.value.where(matchesQuery).toList()))
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar time...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 18),
              filled: true,
              fillColor: AppColors.cardAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allRounds.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isAll = i == 0;
              final roundKey = isAll ? null : allRounds[i - 1].key;
              final selected = _selectedRound == roundKey;
              final label = isAll ? 'Todas' : TeamNamesPt.round(roundKey!);
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedRound = selected ? null : roundKey),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : Colors.white12),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? AppColors.gold : Colors.white54,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: visibleRounds.isEmpty
              ? const Center(
                  child: Text('Nenhum jogo encontrado com esse filtro',
                      style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  itemCount: visibleRounds.length,
                  itemBuilder: (context, i) {
                    final entry = visibleRounds[i];
                    final matches = [...entry.value]
                      ..sort((a, b) => a.date.compareTo(b.date));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            TeamNamesPt.round(entry.key),
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        ...matches.map((m) => MatchCard(
                              match: m,
                              showGroup: false,
                              competitionId: provider.competition.id,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        MatchDetailScreen(match: m)),
                              ),
                            )),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Aba Classificação (ligas) ─────────────────────────────────────────────────

class _LeagueTableTab extends StatelessWidget {
  final CompetitionProvider provider;
  const _LeagueTableTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        StandingsTable(
          standings: provider.standingsFor(),
          competitionId: provider.competition.id,
        ),
      ],
    );
  }
}

// ── Aba Grupos (Eurocopa e afins) ────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final CompetitionProvider provider;
  const _GroupsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final groups = provider.groupNames;
    if (groups.isEmpty) {
      return const Center(
        child: Text('Grupos ainda não definidos',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: groups
          .map((g) => StandingsTable(
                title: TeamNamesPt.group(g),
                standings: provider.standingsFor(group: g),
                highlightTopN: 2,
                competitionId: provider.competition.id,
              ))
          .toList(),
    );
  }
}

// ── Erro ──────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Erro ao carregar dados.\nVerifique sua conexão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
