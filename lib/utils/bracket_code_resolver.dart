import '../models/match.dart';

/// Resolve códigos de chaveamento do formato openfootball da Copa do Mundo —
/// `"1A"`/`"2B"` (posição na classificação do grupo), `"W73"`/`"L101"`
/// (vencedor/perdedor do jogo de número 73/101) e `"3A/B/C/D"` (melhor 3º
/// colocado entre esses grupos) — contra a classificação e os resultados
/// (reais ou simulados) informados pelo chamador.
///
/// Extraído de `Copa2026Provider` (chaveamento real) e `SimulatorProvider`
/// (chaveamento simulado), que tinham essa lógica duplicada palavra por
/// palavra — só a fonte dos resultados e o critério de desempate em caso de
/// placar igual mudam entre os dois, por isso são recebidos como callbacks.
class BracketCodeResolver {
  /// Localiza a partida de número `num` (campo `Match.num`), ou `null` se
  /// ainda não existir/não for conhecida.
  final Match? Function(int num) matchByNum;

  /// Placar `[gols1, gols2]` já decidido para a partida, ou `null` se ainda
  /// não há resultado (real ou simulado).
  final List<int>? Function(Match match) resultOf;

  /// Classificação por grupo (`"Group A"` -> lista ordenada de
  /// `{'team', 'pts', 'sg', 'gp', ...}`), recalculada a cada chamada — o
  /// chamador decide se cacheia ou recalcula por resolução.
  final Map<String, List<Map<String, dynamic>>> Function() standingsByGroup;

  /// Índice do vencedor (0 ou 1) dado o placar, ou `null` se não dá pra
  /// determinar com as regras do chamador (ex.: Copa2026Provider considera
  /// pênaltis registrados; SimulatorProvider trata empate como vitória do
  /// time 1, nunca retornando `null`).
  final int? Function(Match match, List<int> result) winnerIndex;

  /// Quando todos os candidatos a "melhor 3º" de um código já foram
  /// atribuídos a outra vaga, `SimulatorProvider` prefere repetir o melhor
  /// candidato a deixar a vaga em aberto; `Copa2026Provider` prefere deixar
  /// "A definir". Preserva esse comportamento divergente.
  final bool fallbackToTopWhenExhausted;

  final Set<String> _assigned3rd = {};

  BracketCodeResolver({
    required this.matchByNum,
    required this.resultOf,
    required this.standingsByGroup,
    required this.winnerIndex,
    this.fallbackToTopWhenExhausted = false,
  });

  static final RegExp _winnerRe = RegExp(r'^W(\d+)$');
  static final RegExp _loserRe = RegExp(r'^L(\d+)$');
  static final RegExp _positionRe = RegExp(r'^([12])([A-L])$');
  static final RegExp _thirdRe = RegExp(r'^3([A-L](?:/[A-L])*)$');

  /// Detecta os placeholders do chaveamento ("1A"/"2B", "W73"/"L101",
  /// "3A/B/C/D"). Tudo que NÃO casa com esses padrões é nome real de seleção.
  static final RegExp codePattern =
      RegExp(r'^([12][A-L]|[WL]\d+|3[A-L](/[A-L])*)$');

  static bool isCode(String value) => codePattern.hasMatch(value);

  /// Limpa o cache de 3os-colocados já atribuídos — chamar uma vez antes de
  /// resolver o chaveamento inteiro (evita repetir o mesmo time em duas
  /// vagas de "melhor 3º" na mesma passada).
  void resetThirdPlaceAssignment() => _assigned3rd.clear();

  /// Resolve um código para o nome real da seleção, ou retorna o próprio
  /// código quando ainda indefinido.
  String resolve(String code) {
    final w = _winnerRe.firstMatch(code);
    if (w != null) return _matchWinner(int.parse(w.group(1)!)) ?? code;

    final l = _loserRe.firstMatch(code);
    if (l != null) return _matchLoser(int.parse(l.group(1)!)) ?? code;

    final pos = _positionRe.firstMatch(code);
    if (pos != null) {
      final idx = int.parse(pos.group(1)!) - 1;
      final standings = standingsByGroup()['Group ${pos.group(2)}'];
      if (standings != null && idx < standings.length) {
        return standings[idx]['team'] as String;
      }
      return code;
    }

    final third = _thirdRe.firstMatch(code);
    if (third != null) return _resolveBest3rd(third.group(1)!) ?? code;

    return code;
  }

  String? _matchWinner(int num) {
    final m = matchByNum(num);
    if (m == null) return null;
    final r = resultOf(m);
    if (r == null) return null;
    final w = winnerIndex(m, r);
    if (w == null) return null;
    return resolve(w == 0 ? m.team1 : m.team2);
  }

  String? _matchLoser(int num) {
    final m = matchByNum(num);
    if (m == null) return null;
    final r = resultOf(m);
    if (r == null) return null;
    final w = winnerIndex(m, r);
    if (w == null) return null;
    return resolve(w == 0 ? m.team2 : m.team1);
  }

  // Melhor 3º colocado entre os grupos do código "3A/B/C/...", evitando
  // repetir um time já atribuído a outra vaga.
  String? _resolveBest3rd(String lettersJoined) {
    final allowed = lettersJoined.split('/').map((l) => 'Group $l').toSet();
    final candidates = <Map<String, dynamic>>[];
    for (final entry in standingsByGroup().entries) {
      if (!allowed.contains(entry.key)) continue;
      if (entry.value.length >= 3) candidates.add(entry.value[2]);
    }
    candidates.sort((a, b) {
      int c = (b['pts'] as int).compareTo(a['pts'] as int);
      if (c != 0) return c;
      c = (b['sg'] as int).compareTo(a['sg'] as int);
      if (c != 0) return c;
      return (b['gp'] as int).compareTo(a['gp'] as int);
    });

    for (final c in candidates) {
      final team = c['team'] as String;
      if (!_assigned3rd.contains(team)) {
        _assigned3rd.add(team);
        return team;
      }
    }

    if (fallbackToTopWhenExhausted && candidates.isNotEmpty) {
      return candidates.first['team'] as String;
    }
    return null;
  }
}
