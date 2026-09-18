import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../providers/today_matches_provider.dart';
import '../theme/app_colors.dart';
import 'competition_screen.dart';
import 'copa_2026_screen.dart';

/// Ponto de entrada único pra todos os campeonatos que estão rolando agora,
/// incluindo a Copa do Mundo 2026 (em destaque no topo, com sua própria
/// tela rica — grupos, mata-mata real, simulador — em vez da tela genérica
/// das demais). Campeonatos já encerrados (sem jogo futuro na edição atual)
/// saem daqui e ficam acessíveis pela aba História.
class CompetitionsListScreen extends StatefulWidget {
  const CompetitionsListScreen({super.key});

  @override
  State<CompetitionsListScreen> createState() => _CompetitionsListScreenState();
}

class _CompetitionsListScreenState extends State<CompetitionsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodayMatchesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayProvider = context.watch<TodayMatchesProvider>();
    final running = competitionsCatalog
        .where((c) => todayProvider.isCurrentlyRunning(c.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: const Text('Campeonatos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: todayProvider.loading && !todayProvider.loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Copa2026Tile(),
                const SizedBox(height: 10),
                for (final c in running) ...[
                  _CompetitionTile(competition: c),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Campeonatos encerrados (Euro, Copa América, Champions '
                    'League passadas...) ficam na aba História.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Copa 2026 (em destaque) ──────────────────────────────────────────────────

class _Copa2026Tile extends StatelessWidget {
  const _Copa2026Tile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Copa2026Screen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF181818)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'logoCampeonatos_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Copa do Mundo 2026',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text(
                    'Chaveamento real, simulador e bracket · 80 jogos',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

// ── Demais campeonatos ───────────────────────────────────────────────────────

class _CompetitionTile extends StatelessWidget {
  final Competition competition;
  const _CompetitionTile({required this.competition});

  @override
  Widget build(BuildContext context) {
    final isLeague = competition.format == CompetitionFormat.league;
    final editionsLabel = competition.editions.length > 1
        ? '${competition.editions.length} temporadas'
        : competition.editions.first.label;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CompetitionScreen(competition: competition)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(competition.emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(competition.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${isLeague ? 'Liga de pontos corridos' : 'Grupos + mata-mata'} · $editionsLabel',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
