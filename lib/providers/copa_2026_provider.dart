import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/team.dart';
import '../models/stadium.dart';
import '../models/group.dart';
import '../models/local_result.dart';
import '../models/score.dart';
import '../services/openfootball_json_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../utils/bracket_code_resolver.dart';
import '../utils/standings_calculator.dart';

class Copa2026Provider extends ChangeNotifier {
  final OpenFootballJsonService _api = OpenFootballJsonService();
  final LocalStorageService _local = LocalStorageService();
  Timer? _liveTimer;

  List<Match> _matches = [];
  // Base "pura" do openfootball (sem placar ao vivo sobreposto). É a partir
  // dela que `_matches` é recalculado a cada refresh — evita que um placar ao
  // vivo "grude" e nunca mais atualize.
  List<Match> _ofMatches = [];
  List<Team> _teams = [];
  List<Stadium> _stadiums = [];
  List<Group> _groups = [];
  Map<String, LocalResult> _localResults = {};
  // Placares da fonte secundária (rezarahiminia), por matchKey.
  Map<String, Score> _liveScores = {};
  // Contador de ticks do refresh ao vivo (para espaçar o refetch do openfootball).
  int _liveTick = 0;
  // Assinatura do último agendamento de notificações — evita reagendar ~300
  // alarmes a cada resume quando os horários dos jogos não mudaram.
  String? _lastScheduledSig;

  bool _loading = false;
  String? _error;

  List<Match> get matches => _matches;
  List<Team> get teams => _teams;
  List<Stadium> get stadiums => _stadiums;
  List<Group> get groups => _groups;
  Map<String, LocalResult> get localResults => _localResults;
  bool get loading => _loading;
  String? get error => _error;

  List<Match> get todayMatches {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _matches.where((m) => m.date == todayStr).toList();
  }

  List<Match> get upcomingMatches {
    final now = DateTime.now();
    return _matches.where((m) => m.dateTime.isAfter(now)).take(5).toList();
  }

  List<Match> get nextDaysMatches {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 4));
    return _matches
        .where((m) => m.dateTime.isAfter(now) && m.dateTime.isBefore(limit))
        .toList();
  }

  // Artilheiros agregados da Copa 2026
  List<Map<String, dynamic>> get topScorers {
    final Map<String, Map<String, dynamic>> map = {};
    for (final m in _matches) {
      for (final g in m.goals1) {
        if (g.ownGoal) continue;
        final e = map.putIfAbsent(
            g.name, () => {'goals': 0, 'team': m.team1, 'penalties': 0});
        e['goals'] = (e['goals'] as int) + 1;
        if (g.penalty) e['penalties'] = (e['penalties'] as int) + 1;
      }
      for (final g in m.goals2) {
        if (g.ownGoal) continue;
        final e = map.putIfAbsent(
            g.name, () => {'goals': 0, 'team': m.team2, 'penalties': 0});
        e['goals'] = (e['goals'] as int) + 1;
        if (g.penalty) e['penalties'] = (e['penalties'] as int) + 1;
      }
    }
    return (map.entries.map((e) => {'name': e.key, ...e.value}).toList()
      ..sort((a, b) {
        final c = (b['goals'] as int).compareTo(a['goals'] as int);
        return c != 0 ? c : (a['name'] as String).compareTo(b['name'] as String);
      }));
  }

  List<Match> getTeamMatches(String team) =>
      _matches.where((m) => m.team1 == team || m.team2 == team).toList();

  bool get _hasLiveMatch {
    final now = DateTime.now();
    return _matches.any((m) {
      final k = m.dateTime;
      return k.isBefore(now) &&
          k.add(const Duration(minutes: 120)).isAfter(now);
    });
  }

  void _startLiveTimer() {
    _liveTimer?.cancel();
    if (!_hasLiveMatch) return;
    _liveTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _refreshLive());
  }

  Future<void> _refreshLive() async {
    if (!_hasLiveMatch) {
      _liveTimer?.cancel();
      _liveTimer = null;
      return;
    }
    try {
      // A cada tick (60s) busca só os placares ao vivo — leve.
      _liveScores = await _fetchLiveScoresSafe();

      // A base do openfootball (placares oficiais) muda devagar; rebusca só a
      // cada ~5 min em vez de a cada 60s, economizando dados/bateria.
      if (_liveTick % 5 == 0) {
        try {
          final raw = await _api.fetchMatchesRaw(2026);
          await _local.saveMatchesCache(raw);
          _ofMatches = _api.parseMatchesFromRaw(raw);
        } catch (_) {}
      }
      _liveTick++;

      _matches = _withLiveScores(_ofMatches);
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  // Busca os placares da fonte secundária sem nunca lançar (camada opcional).
  Future<Map<String, Score>> _fetchLiveScoresSafe() async {
    try {
      return await _api.fetchLiveScores2026();
    } catch (_) {
      return {};
    }
  }

  // Seleções: tenta a rede (salvando no cache) e cai para o cache offline em
  // caso de falha. Nunca lança — uma seleção ausente não derruba o load.
  Future<List<Team>> _loadTeams() async {
    try {
      final raw = await _api.fetchTeams2026Raw();
      await _local.saveTeamsCache(raw);
      return _api.parseTeams(raw);
    } catch (_) {
      final cached = await _local.loadTeamsCache();
      return cached != null ? _api.parseTeams(cached) : <Team>[];
    }
  }

  // Estádios: mesma estratégia rede → cache offline, sem lançar.
  Future<List<Stadium>> _loadStadiums() async {
    try {
      final raw = await _api.fetchStadiums2026Raw();
      await _local.saveStadiumsCache(raw);
      return _api.parseStadiums(raw);
    } catch (_) {
      final cached = await _local.loadStadiumsCache();
      return cached != null ? _api.parseStadiums(cached) : <Stadium>[];
    }
  }

  // Assinatura dos jogos que importam para o agendamento (chave + horário de
  // início). Independe de placar — atualizar placar ao vivo não reagenda nada.
  String _scheduleSignature(List<Match> matches) => matches
      .map((m) => '${m.matchKey}@${m.dateTime.millisecondsSinceEpoch}')
      .join('|');

  // Usa o placar que aparecer primeiro: o openfootball tem precedência quando
  // já publicou o resultado (mais confiável/correto); o rezarahiminia preenche
  // quando o openfootball ainda não tem — trazendo placar (inclusive ao vivo)
  // o quanto antes.
  List<Match> _withLiveScores(List<Match> matches) {
    if (_liveScores.isEmpty) return matches;
    return matches.map((m) {
      if (m.hasResult) return m; // openfootball já tem o placar -> mantém
      final live = _liveScores[m.matchKey];
      return live != null ? m.copyWith(score: live) : m;
    }).toList();
  }

  // Tarefas auxiliares (notificações e timer ao vivo) que não devem invalidar
  // o carregamento caso falhem — os dados já estão disponíveis nesse ponto.
  Future<void> _runSecondaryTasks() async {
    try {
      if (await NotificationService.instance.isEnabled) {
        // Só reagenda se os horários dos jogos realmente mudaram — evita
        // recriar ~300 alarmes a cada vez que o app volta ao primeiro plano.
        final sig = _scheduleSignature(_matches);
        if (sig != _lastScheduledSig) {
          await NotificationService.instance.scheduleMatchNotifications(_matches);
          _lastScheduledSig = sig;
        }
      }
      _startLiveTimer();
    } catch (_) {}
  }

  /// Recarrega tudo sem mostrar o spinner de tela cheia (usado pelo
  /// pull-to-refresh — o próprio RefreshIndicator já indica o progresso).
  Future<void> refresh() => load(forceReload: true, silent: true);

  Future<void> load({bool forceReload = false, bool silent = false}) async {
    if (_matches.isNotEmpty && !forceReload) {
      await _runSecondaryTasks();
      return;
    }

    if (!silent) _loading = true;
    _error = null;
    notifyListeners();

    try {
      List<Match> loadedMatches;
      try {
        final rawJson = await _api.fetchMatchesRaw(2026);
        await _local.saveMatchesCache(rawJson);
        loadedMatches = _api.parseMatchesFromRaw(rawJson);
      } catch (_) {
        final cached = await _local.loadMatchesCache();
        if (cached != null) {
          loadedMatches = _api.parseMatchesFromRaw(cached);
        } else {
          rethrow;
        }
      }

      // Placares da fonte secundária em paralelo; nunca derruba o load.
      final liveFuture = _fetchLiveScoresSafe();

      // Seleções/estádios agora têm timeout + cache offline próprios e não
      // lançam — uma delas falhar não impede os jogos de aparecerem.
      final others = await Future.wait([
        _loadTeams(),
        _loadStadiums(),
        _local.getAllResults(),
      ]);

      _teams = others[0] as List<Team>;
      _stadiums = others[1] as List<Stadium>;
      _localResults = others[2] as Map<String, LocalResult>;
      _liveScores = await liveFuture;
      _ofMatches = loadedMatches;
      _matches = _withLiveScores(_ofMatches);
      _groups = _api.extractGroupsFromMatches(_matches);

      await _runSecondaryTasks();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> saveResult(String matchKey, int score1, int score2) async {
    await _local.saveResult(matchKey, score1, score2);
    _localResults[matchKey] = LocalResult(
      matchKey: matchKey,
      score1: score1,
      score2: score2,
    );
    notifyListeners();
  }

  Future<void> deleteResult(String matchKey) async {
    await _local.deleteResult(matchKey);
    _localResults.remove(matchKey);
    notifyListeners();
  }

  Stadium? getStadium(String groundName) {
    try {
      return _stadiums.firstWhere(
        (s) =>
            groundName == s.city ||
            groundName.contains(s.city) ||
            s.city.contains(groundName) ||
            groundName.contains(s.name),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Mata-mata / Chaveamento (dados reais) ───────────────────────────────────
  //
  // Os jogos eliminatórios chegam do openfootball com os "times" preenchidos
  // por códigos (ex.: "1A" = 1º do Grupo A, "W73" = vencedor do jogo 73,
  // "3A/B/C/D" = melhor 3º entre esses grupos). Aqui resolvemos esses códigos
  // contra a classificação e os placares REAIS (oficiais/ao vivo ou manuais),
  // sem simulação — só leitura. O que ainda não dá pra determinar fica como o
  // próprio código (a UI mostra "A definir").

  bool get hasKnockoutData => _matches.any((m) => m.group == null);

  List<Match> _roundSorted(String round) =>
      _matches.where((m) => m.round == round).toList()
        ..sort((a, b) => (a.num ?? 0).compareTo(b.num ?? 0));

  List<Match> get roundOf32 => _roundSorted('Round of 32');
  List<Match> get roundOf16 => _roundSorted('Round of 16');
  List<Match> get quarterFinals => _roundSorted('Quarter-final');
  List<Match> get semiFinals => _roundSorted('Semi-final');
  List<Match> get thirdPlace => _roundSorted('Match for third place');
  List<Match> get finalMatch => _roundSorted('Final');

  // Classificação em cache: preenchida por prepareBracket(), chamado uma vez
  // antes de montar o chaveamento na UI.
  Map<String, List<Map<String, dynamic>>> _standingsCache = {};

  late final BracketCodeResolver _resolver = BracketCodeResolver(
    matchByNum: _matchByNum,
    resultOf: bracketResult,
    standingsByGroup: () => _standingsCache,
    winnerIndex: _winnerIndex,
  );

  void prepareBracket() {
    _resolver.resetThirdPlaceAssignment();
    _standingsCache = {
      for (final g in _groups) g.name: getGroupStandings(g.name),
    };
  }

  /// Placar real do jogo (oficial/ao vivo tem precedência; manual completa).
  List<int>? bracketResult(Match m) {
    final apiScore = m.score;
    if (apiScore?.hasResult == true) return [apiScore!.ft[0], apiScore.ft[1]];
    final local = _localResults[m.matchKey];
    if (local != null) return [local.score1, local.score2];
    return null;
  }

  /// Resolve um código de chaveamento para o nome real da seleção, ou retorna
  /// o próprio código quando ainda indefinido.
  String resolveBracketCode(String code) => _resolver.resolve(code);

  /// `true` quando o valor ainda é um código não resolvido (mostrar "A definir").
  bool isCode(String value) => BracketCodeResolver.isCode(value);

  Match? _matchByNum(int num) {
    try {
      return _matches.firstWhere((m) => m.num == num);
    } catch (_) {
      return null;
    }
  }

  // Índice do vencedor (0/1) considerando pênaltis no empate; null se não dá
  // pra determinar (sem placar, ou empate sem disputa de pênaltis registrada).
  int? _winnerIndex(Match m, List<int> r) {
    if (r[0] != r[1]) return r[0] > r[1] ? 0 : 1;
    final p = m.score?.p;
    if (p != null && p.length == 2 && p[0] != p[1]) return p[0] > p[1] ? 0 : 1;
    return null;
  }

  /// Campeão real, quando a final já tem vencedor definido.
  String? get realChampion {
    if (finalMatch.isEmpty) return null;
    final f = finalMatch.first;
    final r = bracketResult(f);
    if (r == null) return null;
    final w = _winnerIndex(f, r);
    if (w == null) return null;
    return resolveBracketCode(w == 0 ? f.team1 : f.team2);
  }

  List<Map<String, dynamic>> getGroupStandings(String groupName) {
    final groupMatches = _matches
        .where((m) => m.group == groupName && m.isGroupStage)
        .toList();

    final group = _groups.firstWhere(
      (g) => g.name == groupName,
      orElse: () => Group(name: groupName, teams: []),
    );

    // Prioridade igual à dos cards: placar automático (rezarahiminia ->
    // openfootball) tem precedência; o manual (bracketResult) preenche
    // quando não há oficial.
    final standings = computeStandings(
      groupMatches,
      scoreOf: bracketResult,
      knownTeams: group.teams,
    );

    return standings.map((row) {
      final teamName = row['team'] as String;
      final team = _teams.firstWhere(
        (t) => t.name == teamName || t.nameNormalised == teamName,
        orElse: () => Team(name: teamName, flagIcon: '🏳️'),
      );
      return {...row, 'flag': team.flagIcon};
    }).toList();
  }
}
