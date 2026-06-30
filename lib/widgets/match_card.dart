import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../models/local_result.dart';
import '../providers/copa_2026_provider.dart';
import '../theme/app_colors.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';
import 'score_entry_dialog.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final bool show2026Actions;
  final bool showGroup;
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.match,
    this.show2026Actions = false,
    this.showGroup = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    LocalResult? localResult;
    if (show2026Actions) {
      final provider = context.watch<Copa2026Provider>();
      localResult = provider.localResults[match.matchKey];
    }

    final score = match.score;
    final hasApiResult = score?.hasResult == true;
    final hasLocalResult = localResult != null;
    final isLive = match.isLive;

    String scoreText = 'x';
    bool isLocal = false;

    if (hasApiResult) {
      scoreText = score!.displayScore;
    } else if (hasLocalResult) {
      scoreText = localResult.displayScore;
      isLocal = true;
    }

    final name1 = TeamNamesPt.translate(match.team1);
    final name2 = TeamNamesPt.translate(match.team2);
    final flag1 = TeamFlags.get(match.team1);
    final flag2 = TeamFlags.get(match.team2);
    final dateFormatted = _formatDate(match.date);
    final hasResult = hasApiResult || hasLocalResult;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLocal
                ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                : hasResult
                    ? const Color(0xFF2A4A2A)
                    : const Color(0xFF243024),
            width: isLocal ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  if (showGroup && match.group != null)
                    _Badge(
                      label: TeamNamesPt.group(match.group!),
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      textColor: const Color(0xFFFFD700),
                    )
                  else
                    Text(TeamNamesPt.round(match.round),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  const Spacer(),
                  if (isLive) ...[
                    const _LiveBadge(),
                    const SizedBox(width: 6),
                  ] else if (match.localTimeLabel.isNotEmpty) ...[
                    Text(match.localTimeLabel,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    const SizedBox(width: 6),
                  ],
                  Text(dateFormatted,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TeamSide(
                      name: name1,
                      flag: flag1,
                      align: TextAlign.right,
                      isWinner: hasResult &&
                          _isWinner(match, localResult, true),
                    ),
                  ),
                  Builder(builder: (_) {
                    // Acento vermelho quando ao vivo, dourado quando há
                    // resultado final/manual, neutro quando ainda não começou.
                    final accent =
                        isLive ? AppColors.live : AppColors.gold;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: hasResult
                            ? accent.withValues(alpha: 0.12)
                            : AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasResult
                              ? accent.withValues(alpha: 0.3)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        scoreText,
                        style: TextStyle(
                          color: hasResult ? accent : Colors.white24,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    );
                  }),
                  Expanded(
                    child: _TeamSide(
                      name: name2,
                      flag: flag2,
                      align: TextAlign.left,
                      isWinner: hasResult &&
                          _isWinner(match, localResult, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on,
                      color: Colors.white24, size: 11),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      match.ground,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLocal) ...[
                    const SizedBox(width: 8),
                    _Badge(
                      label: '📝 Local',
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      textColor: const Color(0xFFFFD700),
                    ),
                  ],
                ],
              ),
              if (show2026Actions && !hasApiResult) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openScoreDialog(context, localResult),
                    icon: Icon(
                        hasLocalResult ? Icons.edit : Icons.add,
                        size: 14),
                    label: Text(hasLocalResult
                        ? 'Editar resultado'
                        : 'Inserir resultado'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      side: BorderSide(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isWinner(Match match, LocalResult? localResult, bool isTeam1) {
    final score = match.score;
    int? g1, g2;
    if (score?.hasResult == true) {
      g1 = score!.ft[0];
      g2 = score.ft[1];
    } else if (localResult != null) {
      g1 = localResult.score1;
      g2 = localResult.score2;
    }
    if (g1 == null || g2 == null || g1 == g2) return false;
    return isTeam1 ? g1 > g2 : g2 > g1;
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd/MM', 'pt_BR').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _openScoreDialog(
      BuildContext context, LocalResult? existing) async {
    final provider = context.read<Copa2026Provider>();
    final result = await showDialog(
      context: context,
      builder: (_) =>
          ScoreEntryDialog(match: match, existingResult: existing),
    );
    if (result == 'delete') {
      await provider.deleteResult(match.matchKey);
    } else if (result is List<int> && result.length == 2) {
      await provider.saveResult(match.matchKey, result[0], result[1]);
    }
  }
}

class _TeamSide extends StatelessWidget {
  final String name;
  final String flag;
  final TextAlign align;
  final bool isWinner;

  const _TeamSide({
    required this.name,
    required this.flag,
    required this.align,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      if (flag.isNotEmpty) ...[
        Text(flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          name,
          textAlign: align,
          style: TextStyle(
            color: isWinner ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight:
                isWinner ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    return align == TextAlign.right
        ? Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: children.reversed.toList(),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: children,
          );
  }
}

// Selo "AO VIVO" com pontinho que pulsa suavemente.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.25).animate(_controller),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'AO VIVO',
            style: TextStyle(
              color: AppColors.live,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(color: textColor, fontSize: 10)),
    );
  }
}
