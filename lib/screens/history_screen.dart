import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../providers/history_provider.dart';
import '../providers/today_matches_provider.dart';
import '../services/openfootball_json_service.dart';
import 'competition_screen.dart';
import 'copa_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _allYears = OpenFootballJsonService.historicalYears;

  @override
  Widget build(BuildContext context) {
    final todayProvider = context.watch<TodayMatchesProvider>();
    final pastCompetitions = competitionsCatalog
        .where((c) => !todayProvider.isCurrentlyRunning(c.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('📖 História da Copa',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (pastCompetitions.isNotEmpty)
            PopupMenuButton<Competition>(
              tooltip: 'Outros campeonatos encerrados',
              icon: const Icon(Icons.emoji_events_outlined, color: Colors.white),
              onSelected: (c) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CompetitionScreen(competition: c)),
              ),
              itemBuilder: (context) => pastCompetitions
                  .map((c) => PopupMenuItem<Competition>(
                        value: c,
                        child: Text('${c.emoji} ${c.name}'),
                      ))
                  .toList(),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allYears.length,
        itemBuilder: (ctx, i) {
          final year = _allYears[_allYears.length - 1 - i]; // mais recente primeiro
          final info = worldCupInfo[year];

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CopaDetailScreen(year: year),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF202020), Color(0xFF162316)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Ano
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$year',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bandeira do campeão
                    Text(
                      info?['flag'] ?? '🏆',
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info?['champion'] == '?'
                                ? '🏆 A definir'
                                : info?['champion'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sede: ${info?['host'] ?? ''}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
