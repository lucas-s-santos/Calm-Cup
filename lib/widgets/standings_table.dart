import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/team_names_pt.dart';
import 'team_badge.dart';

/// Tabela de classificação reutilizável — mesmo visual já usado na aba
/// Grupos da Copa 2026, mas recebendo a lista de linhas já calculada (ver
/// `computeStandings`) em vez de depender do `Copa2026Provider`.
class StandingsTable extends StatelessWidget {
  final String? title;
  final List<Map<String, dynamic>> standings;

  /// Quando definido, destaca as `highlightTopN` primeiras posições (ex.:
  /// classificados de um grupo). `null` não destaca ninguém.
  final int? highlightTopN;

  /// Id da competição — usado só pra resolver escudo real de clube via
  /// `TeamBadge` (seleções nacionais já caem na bandeira sem precisar disso).
  final String? competitionId;

  const StandingsTable({
    super.key,
    this.title,
    required this.standings,
    this.highlightTopN,
    this.competitionId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          if (title != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.greenHeader,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Text(
                title!,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: const [
                SizedBox(width: 26),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Time',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 10))),
                _CellH('PJ'),
                _CellH('V'),
                _CellH('E'),
                _CellH('D'),
                _CellH('GP', width: 24),
                _CellH('GC', width: 24),
                _CellH('SG', width: 28),
                _CellH('PTS', width: 30),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (standings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Nenhum jogo disputado ainda',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...standings.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final qualified = highlightTopN != null && idx < highlightTopN!;
              final teamName = s['team'] as String;

              return Container(
                decoration: BoxDecoration(
                  color: qualified
                      ? AppColors.green.withValues(alpha: 0.25)
                      : null,
                  borderRadius: idx == standings.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(13))
                      : null,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text('${idx + 1}',
                          style: TextStyle(
                              color: qualified
                                  ? AppColors.gold
                                  : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 22,
                      child: TeamBadge(
                        teamName: teamName,
                        competitionId: competitionId,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        TeamNamesPt.translate(teamName),
                        style: TextStyle(
                            color: qualified ? Colors.white : Colors.white60,
                            fontSize: 12,
                            fontWeight: qualified
                                ? FontWeight.w600
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CellD('${s['pj']}'),
                    _CellD('${s['v']}'),
                    _CellD('${s['e']}'),
                    _CellD('${s['d']}'),
                    _CellD('${s['gp']}', width: 24),
                    _CellD('${s['gc']}', width: 24),
                    _CellD('${s['sg']}', width: 28),
                    _CellD(
                      '${s['pts']}',
                      width: 30,
                      bold: true,
                      color: qualified ? AppColors.gold : Colors.white54,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CellH extends StatelessWidget {
  final String text;
  final double width;
  const _CellH(this.text, {this.width = 26});

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

class _CellD extends StatelessWidget {
  final String text;
  final double width;
  final bool bold;
  final Color color;
  const _CellD(this.text,
      {this.width = 26, this.bold = false, this.color = Colors.white60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}
