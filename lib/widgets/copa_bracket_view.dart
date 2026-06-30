import 'package:flutter/material.dart';
import '../providers/copa_2026_provider.dart';
import '../models/match.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';

/// Chaveamento (mata-mata) da Copa com dados REAIS — somente leitura.
///
/// Mostra os confrontos das eliminatórias resolvendo os códigos da API
/// ("1A", "W73", "3A/B/C/D") contra a classificação e os placares reais.
/// Quem ainda não está definido aparece como "A definir".
class CopaBracketView extends StatelessWidget {
  final Copa2026Provider provider;
  const CopaBracketView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasKnockoutData) {
      return _EmptyState();
    }

    provider.prepareBracket();

    final r32 = provider.roundOf32;
    final r16 = provider.roundOf16;
    final qf = provider.quarterFinals;
    final sf = provider.semiFinals;
    final fin = provider.finalMatch;
    final third = provider.thirdPlace;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const _Legend(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r32.isNotEmpty) ...[
                _RoundColumn(label: 'Rodada de 32', matches: r32, provider: provider),
                _ConnectorColumn(count: r32.length),
              ],
              _RoundColumn(label: 'Oitavas', matches: r16, provider: provider),
              _ConnectorColumn(count: r16.length),
              _RoundColumn(label: 'Quartas', matches: qf, provider: provider),
              _ConnectorColumn(count: qf.length),
              _RoundColumn(label: 'Semifinais', matches: sf, provider: provider),
              _ConnectorColumn(count: sf.length),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (fin.isNotEmpty) ...[
                    const _RoundLabel(label: 'Final', isFinal: true),
                    _BracketMatchCard(
                        match: fin.first, provider: provider, highlight: true),
                  ],
                  if (third.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const _RoundLabel(label: '3º Lugar'),
                    _BracketMatchCard(match: third.first, provider: provider),
                  ],
                  if (provider.realChampion != null) ...[
                    const SizedBox(height: 20),
                    _ChampionBadge(name: provider.realChampion!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Legenda ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: Color(0xFFFFD700), size: 15),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Os classificados aparecem aqui conforme os grupos são decididos. '
              'Arraste para o lado para ver todas as fases.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coluna de uma fase ──────────────────────────────────────────────────────

class _RoundColumn extends StatelessWidget {
  final String label;
  final List<Match> matches;
  final Copa2026Provider provider;

  const _RoundColumn({
    required this.label,
    required this.matches,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RoundLabel(label: label),
        for (final m in matches)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _BracketMatchCard(match: m, provider: provider),
          ),
      ],
    );
  }
}

class _RoundLabel extends StatelessWidget {
  final String label;
  final bool isFinal;
  const _RoundLabel({required this.label, this.isFinal = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFinal
            ? const Color(0xFFFFD700).withValues(alpha: 0.15)
            : const Color(0xFF1A472A),
        borderRadius: BorderRadius.circular(6),
        border: isFinal
            ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Card de confronto ───────────────────────────────────────────────────────

class _BracketMatchCard extends StatelessWidget {
  final Match match;
  final Copa2026Provider provider;
  final bool highlight;

  const _BracketMatchCard({
    required this.match,
    required this.provider,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t1raw = provider.resolveBracketCode(match.team1);
    final t2raw = provider.resolveBracketCode(match.team2);
    final result = provider.bracketResult(match);

    final tbd1 = provider.isCode(t1raw);
    final tbd2 = provider.isCode(t2raw);

    final t1 = tbd1 ? 'A definir' : TeamNamesPt.translate(t1raw);
    final t2 = tbd2 ? 'A definir' : TeamNamesPt.translate(t2raw);
    final f1 = tbd1 ? '' : TeamFlags.get(t1raw);
    final f2 = tbd2 ? '' : TeamFlags.get(t2raw);

    // Pênaltis (quando houver) para destacar o vencedor no empate.
    final pens = match.score?.p;
    int? winnerIdx;
    if (result != null) {
      if (result[0] != result[1]) {
        winnerIdx = result[0] > result[1] ? 0 : 1;
      } else if (pens != null && pens.length == 2 && pens[0] != pens[1]) {
        winnerIdx = pens[0] > pens[1] ? 0 : 1;
      }
    }

    return Container(
      width: 172,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF1E1A00) : const Color(0xFF1A2A1A),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlight
              ? const Color(0xFFFFD700)
              : result != null
                  ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                  : Colors.white12,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          _TeamRow(
            name: t1,
            flag: f1,
            tbd: tbd1,
            score: result?[0],
            pen: pens != null && pens.length == 2 ? pens[0] : null,
            isWinner: winnerIdx == 0,
          ),
          const Divider(height: 1, color: Colors.white12),
          _TeamRow(
            name: t2,
            flag: f2,
            tbd: tbd2,
            score: result?[1],
            pen: pens != null && pens.length == 2 ? pens[1] : null,
            isWinner: winnerIdx == 1,
          ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final String flag;
  final bool tbd;
  final int? score;
  final int? pen;
  final bool isWinner;

  const _TeamRow({
    required this.name,
    this.flag = '',
    this.tbd = false,
    this.score,
    this.pen,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      color: isWinner ? const Color(0xFFFFD700).withValues(alpha: 0.08) : null,
      child: Row(
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tbd
                    ? Colors.white24
                    : isWinner
                        ? const Color(0xFFFFD700)
                        : Colors.white70,
                fontSize: 11,
                fontStyle: tbd ? FontStyle.italic : FontStyle.normal,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (pen != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                '($pen)',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          if (score != null)
            SizedBox(
              width: 16,
              child: Text(
                '$score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isWinner ? const Color(0xFFFFD700) : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Conectores entre as fases ───────────────────────────────────────────────

class _ConnectorColumn extends StatelessWidget {
  final int count;
  const _ConnectorColumn({required this.count});

  @override
  Widget build(BuildContext context) {
    const cardH = 46.0;
    const gap = 4.0;
    const roundLabelH = 30.0;

    return SizedBox(
      width: 20,
      child: CustomPaint(
        size: Size(20, roundLabelH + count * (cardH + gap)),
        painter: _ConnectorPainter(count: count),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final int count;
  _ConnectorPainter({required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A4A2A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const roundLabelH = 30.0;
    const cardH = 46.0;
    const gap = 4.0;

    final pairs = count ~/ 2;
    for (int i = 0; i < pairs; i++) {
      final topIdx = i * 2;
      final botIdx = topIdx + 1;
      final topY = roundLabelH + topIdx * (cardH + gap) + cardH / 2;
      final botY = roundLabelH + botIdx * (cardH + gap) + cardH / 2;
      final midY = (topY + botY) / 2;

      canvas.drawLine(Offset(0, topY), Offset(10, topY), paint);
      canvas.drawLine(Offset(0, botY), Offset(10, botY), paint);
      canvas.drawLine(Offset(10, topY), Offset(10, botY), paint);
      canvas.drawLine(Offset(10, midY), Offset(20, midY), paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.count != count;
}

// ── Campeão ─────────────────────────────────────────────────────────────────

class _ChampionBadge extends StatelessWidget {
  final String name;
  const _ChampionBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final namePt = TeamNamesPt.translate(name);
    final flag = TeamFlags.get(name);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A00), Color(0xFF1A3A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 4),
          const Text(
            'CAMPEÃO',
            style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5),
          ),
          const SizedBox(height: 6),
          if (flag.isNotEmpty) Text(flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            namePt,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Vazio ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Text('🗂️', style: TextStyle(fontSize: 44)),
              SizedBox(height: 12),
              Text(
                'Mata-mata ainda não disponível',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'O chaveamento aparece quando a fase\nde grupos estiver definida.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
