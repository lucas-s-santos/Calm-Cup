import 'package:flutter/material.dart';
import '../providers/simulator_provider.dart';
import '../models/match.dart';
import '../utils/team_flags.dart';
import '../utils/team_names_pt.dart';

class BracketWidget extends StatelessWidget {
  final SimulatorProvider provider;
  const BracketWidget({super.key, required this.provider});

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
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('📊', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Simule os grupos para ver o bracket',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    provider.reset3rdAssignment();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: _buildBracket(),
      ),
    );
  }

  Widget _buildBracket() {
    final r32 = provider.roundOf32;
    final r16 = provider.roundOf16;
    final qf = provider.quarterFinals;
    final sf = provider.semiFinals;
    final fin = provider.final_;
    final third = provider.thirdPlace;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundColumn(label: 'Rodada de 32', matches: r32, provider: provider),
        _ConnectorColumn(count: r32.length, nextCount: r16.length),
        _RoundColumn(label: 'Oitavas', matches: r16, provider: provider),
        _ConnectorColumn(count: r16.length, nextCount: qf.length),
        _RoundColumn(label: 'Quartas', matches: qf, provider: provider),
        _ConnectorColumn(count: qf.length, nextCount: sf.length),
        _RoundColumn(label: 'Semifinais', matches: sf, provider: provider),
        _ConnectorColumn(count: sf.length, nextCount: fin.length),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (fin.isNotEmpty) ...[
              const _RoundLabel(label: 'Final', isFinal: true),
              _BracketMatchCard(
                  match: fin.first, provider: provider, highlight: true),
            ],
            const SizedBox(height: 16),
            if (third.isNotEmpty) ...[
              const _RoundLabel(label: '3º Lugar'),
              _BracketMatchCard(match: third.first, provider: provider),
            ],
            if (provider.projectedChampion != null) ...[
              const SizedBox(height: 20),
              _ChampionBadge(name: provider.projectedChampion!),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Round Column ──────────────────────────────────────────────────────────────

class _RoundColumn extends StatelessWidget {
  final String label;
  final List<Match> matches;
  final SimulatorProvider provider;

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

// ── Round Label ───────────────────────────────────────────────────────────────

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
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: isFinal
            ? Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
            color: isFinal ? const Color(0xFFFFD700) : const Color(0xFFFFD700),
            fontSize: 11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Bracket Match Card ────────────────────────────────────────────────────────

class _BracketMatchCard extends StatelessWidget {
  final Match match;
  final SimulatorProvider provider;
  final bool highlight;

  const _BracketMatchCard({
    required this.match,
    required this.provider,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t1raw = provider.resolveCode(match.team1);
    final t2raw = provider.resolveCode(match.team2);
    final result = provider.getResult(match.matchKey);

    final tbd1 = t1raw == match.team1 && match.team1.length > 2;
    final tbd2 = t2raw == match.team2 && match.team2.length > 2;

    final t1 = tbd1 ? '?' : TeamNamesPt.translate(t1raw);
    final t2 = tbd2 ? '?' : TeamNamesPt.translate(t2raw);
    final f1 = tbd1 ? '' : TeamFlags.get(t1raw);
    final f2 = tbd2 ? '' : TeamFlags.get(t2raw);

    String? winner;
    if (result != null) {
      winner = result[0] >= result[1] ? t1 : t2;
    }

    return Container(
      width: 170,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF1E1A00)
            : const Color(0xFF1A1A1A),
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
            score: result?[0],
            isWinner: winner == t1 && winner != null,
          ),
          Divider(height: 1, color: Colors.white12),
          _TeamRow(
            name: t2,
            flag: f2,
            score: result?[1],
            isWinner: winner == t2 && winner != null,
          ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final String flag;
  final int? score;
  final bool isWinner;

  const _TeamRow({
    required this.name,
    this.flag = '',
    this.score,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      color: isWinner
          ? const Color(0xFFFFD700).withValues(alpha: 0.08)
          : null,
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
                color: isWinner ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 11,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (score != null)
            Container(
              width: 20,
              alignment: Alignment.center,
              child: Text(
                '$score',
                style: TextStyle(
                  color: isWinner
                      ? const Color(0xFFFFD700)
                      : Colors.white38,
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

// ── Connector Column ──────────────────────────────────────────────────────────

class _ConnectorColumn extends StatelessWidget {
  final int count;
  final int nextCount;

  const _ConnectorColumn({required this.count, required this.nextCount});

  @override
  Widget build(BuildContext context) {
    const cardH = 46.0;
    const gap = 4.0;
    const roundLabelH = 30.0;

    return SizedBox(
      width: 20,
      child: CustomPaint(
        size: Size(20, roundLabelH + count * (cardH + gap)),
        painter: _ConnectorPainter(count: count, nextCount: nextCount),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final int count;
  final int nextCount;

  _ConnectorPainter({required this.count, required this.nextCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E2E2E)
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
  bool shouldRepaint(_ConnectorPainter old) =>
      old.count != count || old.nextCount != nextCount;
}

// ── Champion Badge ────────────────────────────────────────────────────────────

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
          if (flag.isNotEmpty)
            Text(flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            namePt,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
