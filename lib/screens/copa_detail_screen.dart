import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../utils/team_names_pt.dart';
import '../widgets/match_card.dart';
import 'match_detail_screen.dart';

class CopaDetailScreen extends StatefulWidget {
  final int year;

  const CopaDetailScreen({super.key, required this.year});

  @override
  State<CopaDetailScreen> createState() => _CopaDetailScreenState();
}

class _CopaDetailScreenState extends State<CopaDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadYear(widget.year);
    });
  }

  String _translateRound(String round) {
    if (round.startsWith('Group')) return TeamNamesPt.group(round);
    return TeamNamesPt.round(round);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final info = worldCupInfo[widget.year];
    final isLoading = provider.isLoading(widget.year);
    final error = provider.getError(widget.year);

    final grouped = provider.groupByRound(widget.year);
    final rounds = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF1E1E1E),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Copa ${widget.year}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (info != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E1E), Color(0xFF0D2A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Text(info['flag']!,
                        style: const TextStyle(fontSize: 48)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info['champion'] == '?'
                                ? '🏆 A definir'
                                : '🏆 ${info['champion']}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sede: ${info['host']}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              ),
            )
          else if (error != null)
            SliverFillRemaining(
              child: Center(
                child: error.contains('NOT_FOUND') // 404 da API
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📭',
                              style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text(
                            'Dados não disponíveis',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'A API não possui histórico\ndesta edição da Copa.',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off,
                              color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          const Text('Erro ao carregar',
                              style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => provider.loadYear(widget.year),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFD700),
                                foregroundColor: Colors.black),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
              ),
            )
          else ...[
            if (provider.getTopScorers(widget.year).isNotEmpty) ...[
              _SliverSectionTitle(title: '⚽ Artilheiros'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.getTopScorers(widget.year).length,
                    itemBuilder: (ctx, i) {
                      final s = provider.getTopScorers(widget.year)[i];
                      return Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202020),
                          borderRadius: BorderRadius.circular(10),
                          border: i == 0
                              ? Border.all(
                                  color: const Color(0xFFFFD700), width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${i == 0 ? "🥇" : i == 1 ? "🥈" : i == 2 ? "🥉" : "${i + 1}."} ${s['name']}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                '${s['goals']} gol${s['goals'] == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Color(0xFFFFD700), fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            ...rounds.map((round) {
              final roundMatches = grouped[round]!;
              final roundLabel = _translateRound(round);
              return [
                _SliverSectionTitle(title: roundLabel),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => MatchCard(
                      match: roundMatches[i],
                      showGroup: roundMatches[i].group != null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MatchDetailScreen(match: roundMatches[i]),
                        ),
                      ),
                    ),
                    childCount: roundMatches.length,
                  ),
                ),
              ];
            }).expand((l) => l),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

class _SliverSectionTitle extends SliverToBoxAdapter {
  _SliverSectionTitle({required String title})
      : super(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
}
