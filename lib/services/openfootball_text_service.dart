import '../models/competition.dart';
import '../models/match.dart';
import '../models/score.dart';

const _weekdays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};

const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

/// Parseia o formato de texto legado ("súmula") do openfootball, usado por
/// competições sem JSON — Brasileirão, Libertadores, Copa América e boa
/// parte das temporadas da Champions League. Duas gramáticas confirmadas
/// contra arquivos reais (ver [TextDialect]), cada uma com seu parser
/// próprio; ambas compartilham o parsing de placar (`_parseScoreBlob`), já
/// que os dois formatos usam a mesma notação pra pênaltis/prorrogação.
///
/// Tolerante por design: uma linha que não bate com o padrão esperado é
/// ignorada, nunca derruba o parse inteiro — súmulas reais têm ruído
/// (linhas de artilheiro, comentários, agregados de ida-e-volta) que não
/// vale a pena modelar por completo no MVP.
class OpenFootballTextService {
  List<Match> parseMatches(String raw, TextDialect dialect) {
    switch (dialect) {
      case TextDialect.dateBlock:
        return _parseDateBlock(raw);
      case TextDialect.singleLineWithVenue:
        return _parseSingleLineWithVenue(raw);
    }
  }

  // ── Dialeto A: bloco de data ────────────────────────────────────────────
  //
  // ▪ Estágio, Rodada
  //   Weekday Mon Day[ Year]
  //     HH:MM  Time1            v Time2              N-N (ht-ht)
  //            Time3            v Time4              N-N
  //
  // O horário e a data só aparecem na primeira linha do bloco — linhas
  // seguintes (mesma data/horário) vêm só indentadas, sem repetir.

  static final _dateLineRe =
      RegExp(r'^(\w{3}) (\w{3}) (\d{1,2})(?: (\d{4}))?$');
  static final _matchLineARe =
      RegExp(r'^(?:(\d{1,2}:\d{2})\s+)?(.+?)\s+v\s+(.+?)\s{2,}(\d.*)$');
  // Partida futura, ainda sem placar (a temporada corrente sempre tem jogos
  // à frente da data de hoje) — mesma forma da linha acima, só sem o placar
  // no fim. Testada só depois da com placar (senão "engoliria" o placar
  // dentro do nome do time2).
  static final _matchLineANoScoreRe =
      RegExp(r'^(?:(\d{1,2}:\d{2})\s+)?(.+?)\s+v\s+(.+)$');

  List<Match> _parseDateBlock(String raw) {
    final result = <Match>[];
    String round = '';
    String date = '';
    String time = '';

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('=') || trimmed.startsWith('#')) {
        continue;
      }

      if (trimmed.startsWith('▪')) {
        round = trimmed.substring(1).trim();
        time = '';
        continue;
      }

      final dateMatch = _dateLineRe.firstMatch(trimmed);
      if (dateMatch != null) {
        final month = _months[dateMatch.group(2)];
        final day = int.tryParse(dateMatch.group(3) ?? '');
        if (month != null && day != null) {
          final yearStr = dateMatch.group(4);
          if (yearStr != null) {
            date = _isoDate(int.parse(yearStr), month, day);
          } else if (date.isNotEmpty) {
            // Mantém o ano já conhecido, só troca mês/dia.
            final year = int.parse(date.substring(0, 4));
            date = _isoDate(year, month, day);
          }
          time = '';
        }
        continue;
      }

      // Linha de partida: só tenta se já temos uma data corrente — evita
      // interpretar ruído/linhas soltas do topo do arquivo como jogo.
      if (date.isEmpty) continue;

      final scored = _matchLineARe.firstMatch(trimmed);
      if (scored != null) {
        final lineTime = scored.group(1);
        if (lineTime != null) time = lineTime;
        if (time.isEmpty) continue; // sem horário conhecido, ignora a linha

        result.add(Match(
          round: round,
          date: date,
          time: time,
          team1: scored.group(2)!.trim(),
          team2: scored.group(3)!.trim(),
          ground: '',
          score: _parseScoreBlob(scored.group(4)!.trim()),
        ));
        continue;
      }

      // Sem placar (jogo futuro, ainda não disputado). "[postponed]"/
      // "[cancelled]" não são nome de time — se sobrar isso no time2, ignora
      // a linha em vez de virar um jogo com nome de time errado.
      final noScore = _matchLineANoScoreRe.firstMatch(trimmed);
      if (noScore == null) continue;
      final team2 = noScore.group(3)!.trim();
      if (team2.contains('[')) continue;

      final lineTime = noScore.group(1);
      if (lineTime != null) time = lineTime;
      if (time.isEmpty) continue;

      result.add(Match(
        round: round,
        date: date,
        time: time,
        team1: noScore.group(2)!.trim(),
        team2: team2,
        ground: '',
        score: null,
      ));
    }

    return result;
  }

  // ── Dialeto B: uma partida por linha, com local ─────────────────────────
  //
  // Group A  |  Time1  Time2  Time3  Time4
  // ▪ Group A
  // Weekday Mon Day HH:MM UTC±N   Time1   N-N[ pen.|a.e.t. (N-N)]   Time2  @ Local

  static final _groupLineRe = RegExp(r'^Group ([A-Z])\s*\|\s*(.+)$');

  // O espaçamento entre time1 e o placar não é confiável (às vezes 1 espaço
  // só, às vezes vários) — por isso o placar é localizado pela própria
  // gramática (dígito-traço-dígito) em vez de contar espaços; team1 é tudo
  // antes dele, team2/local é tudo depois, até o "@".
  static final _dialectBPrefixRe = RegExp(
    r'^(\w{3}) (\w{3}) (\d{1,2}) (\d{1,2}:\d{2}) (UTC[+-]\d+)\s+(.*)$',
  );
  static final _scoreInLineRe = RegExp(
    r'\d+-\d+(?:\s*(?:pen\.|a\.e\.t\.)\s*\(\d+-\d+(?:,\s*\d+-\d+)?\))?',
  );
  static final _team2VenueRe = RegExp(r'^\s*(.+?)\s+@\s*(.+)$');

  List<Match> _parseSingleLineWithVenue(String raw) {
    final lines = raw.split('\n');

    // Ano: só aparece no título ("= Copa América 2024 ..."), nunca por linha.
    final yearMatch = RegExp(r'\b(\d{4})\b').firstMatch(lines.first);
    final year = yearMatch != null ? int.parse(yearMatch.group(1)!) : 0;

    final result = <Match>[];
    String round = '';
    String? group;

    for (final rawLine in lines) {
      final line = rawLine.split('#').first.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('=')) continue;

      final groupDecl = _groupLineRe.firstMatch(trimmed);
      if (groupDecl != null) continue; // membership já foi resolvida — só
      // precisamos do nome do grupo quando estivermos dentro da seção dele.

      if (trimmed.startsWith('▪')) {
        final header = trimmed.substring(1).trim();
        if (header.contains('|')) continue; // "Matchday N | intervalo de datas"
        round = header;
        group = RegExp(r'^Group [A-Z]$').hasMatch(header) ? header : null;
        continue;
      }

      final weekday = trimmed.length >= 3 ? trimmed.substring(0, 3) : '';
      if (!_weekdays.contains(weekday)) continue; // linha de artilheiro etc.

      final prefix = _dialectBPrefixRe.firstMatch(trimmed);
      if (prefix == null) continue;

      final month = _months[prefix.group(2)];
      final day = int.tryParse(prefix.group(3) ?? '');
      if (month == null || day == null || year == 0) continue;

      final rest = prefix.group(6)!;
      final scoreMatch = _scoreInLineRe.firstMatch(rest);
      if (scoreMatch == null) continue;

      final team1 = rest.substring(0, scoreMatch.start).trim();
      final team2Venue =
          _team2VenueRe.firstMatch(rest.substring(scoreMatch.end));
      if (team2Venue == null) continue;

      result.add(Match(
        round: round,
        date: _isoDate(year, month, day),
        time: '${prefix.group(4)} ${prefix.group(5)}',
        team1: team1,
        team2: team2Venue.group(1)!.trim(),
        group: group,
        ground: team2Venue.group(2)!.trim(),
        score: _parseScoreBlob(scoreMatch.group(0)!),
      ));
    }

    return result;
  }

  // ── Placar (compartilhado pelos dois dialetos) ──────────────────────────
  //
  // "N-M"                          -> ft
  // "N-M (H-H)"                    -> ft + ht
  // "N-M pen. (H-H)"               -> ft=(H-H), p=(N-M)      [partida única]
  // "N-M a.e.t. (H-H)"             -> ft=(H-H), et=(N-M)     [partida única]
  // Qualquer coisa mais complexa (agregado de ida-e-volta com vírgula,
  // "pen." + "a.e.t." na mesma linha — só visto na Final da Champions) cai
  // no caso simples: mostra só o placar principal, sem lançar.

  static final _leadRe = RegExp(r'^(\d+)-(\d+)');
  static final _singleDecidedRe =
      RegExp(r'^\d+-\d+\s*(pen\.|a\.e\.t\.)\s*\((\d+)-(\d+)\)\s*$');
  static final _withHtRe = RegExp(r'^\d+-\d+\s*\((\d+)-(\d+)\)\s*$');

  Score _parseScoreBlob(String blob) {
    final lead = _leadRe.firstMatch(blob);
    if (lead == null) return const Score(ft: []);
    final leadPair = [int.parse(lead.group(1)!), int.parse(lead.group(2)!)];

    final decided = _singleDecidedRe.firstMatch(blob);
    if (decided != null) {
      final paren = [int.parse(decided.group(2)!), int.parse(decided.group(3)!)];
      return decided.group(1) == 'pen.'
          ? Score(ft: paren, p: leadPair)
          : Score(ft: paren, et: leadPair);
    }

    final withHt = _withHtRe.firstMatch(blob);
    if (withHt != null) {
      return Score(
        ft: leadPair,
        ht: [int.parse(withHt.group(1)!), int.parse(withHt.group(2)!)],
      );
    }

    return Score(ft: leadPair);
  }

  String _isoDate(int year, int month, int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
