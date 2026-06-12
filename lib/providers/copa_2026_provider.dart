import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/team.dart';
import '../models/stadium.dart';
import '../models/group.dart';
import '../models/local_result.dart';
import '../models/score.dart';
import '../services/world_cup_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class Copa2026Provider extends ChangeNotifier {
  final WorldCupApiService _api = WorldCupApiService();
  final LocalStorageService _local = LocalStorageService();
  Timer? _liveTimer;

  List<Match> _matches = [];
  List<Team> _teams = [];
  List<Stadium> _stadiums = [];
  List<Group> _groups = [];
  Map<String, LocalResult> _localResults = {};
  // Placares da fonte secundária (rezarahiminia), por matchKey.
  Map<String, Score> _liveScores = {};

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
      final raw = await _api.fetchMatchesRaw(2026);
      await _local.saveMatchesCache(raw);
      final of = _api.parseMatchesFromRaw(raw);
      _liveScores = await _fetchLiveScoresSafe();
      _matches = _withLiveScores(of);
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
        await NotificationService.instance.scheduleMatchNotifications(_matches);
      }
      _startLiveTimer();
    } catch (_) {}
  }

  Future<void> load({bool forceReload = false}) async {
    if (_matches.isNotEmpty && !forceReload) {
      await _runSecondaryTasks();
      return;
    }

    _loading = true;
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

      final others = await Future.wait([
        _api.fetchTeams2026(),
        _api.fetchStadiums2026(),
        _local.getAllResults(),
      ]);

      _teams = others[0] as List<Team>;
      _stadiums = others[1] as List<Stadium>;
      _localResults = others[2] as Map<String, LocalResult>;
      _liveScores = await liveFuture;
      _matches = _withLiveScores(loadedMatches);
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

  List<Map<String, dynamic>> getGroupStandings(String groupName) {
    final groupMatches = _matches
        .where((m) => m.group == groupName && m.isGroupStage)
        .toList();

    final Map<String, Map<String, int>> standings = {};

    void addTeam(String team) {
      standings.putIfAbsent(
          team,
          () =>
              {'pts': 0, 'pj': 0, 'v': 0, 'e': 0, 'd': 0, 'gp': 0, 'gc': 0});
    }

    for (final match in groupMatches) {
      final localResult = _localResults[match.matchKey];
      final apiScore = match.score;

      // Prioridade igual à dos cards: placar automático (rezarahiminia ->
      // openfootball) tem precedência; o manual preenche quando não há oficial.
      int? g1, g2;
      if (apiScore?.hasResult == true) {
        g1 = apiScore!.ft[0];
        g2 = apiScore.ft[1];
      } else if (localResult != null) {
        g1 = localResult.score1;
        g2 = localResult.score2;
      }

      if (g1 == null || g2 == null) continue;

      addTeam(match.team1);
      addTeam(match.team2);

      standings[match.team1]!['pj'] = standings[match.team1]!['pj']! + 1;
      standings[match.team2]!['pj'] = standings[match.team2]!['pj']! + 1;
      standings[match.team1]!['gp'] = standings[match.team1]!['gp']! + g1;
      standings[match.team1]!['gc'] = standings[match.team1]!['gc']! + g2;
      standings[match.team2]!['gp'] = standings[match.team2]!['gp']! + g2;
      standings[match.team2]!['gc'] = standings[match.team2]!['gc']! + g1;

      if (g1 > g2) {
        standings[match.team1]!['pts'] = standings[match.team1]!['pts']! + 3;
        standings[match.team1]!['v'] = standings[match.team1]!['v']! + 1;
        standings[match.team2]!['d'] = standings[match.team2]!['d']! + 1;
      } else if (g1 == g2) {
        standings[match.team1]!['pts'] = standings[match.team1]!['pts']! + 1;
        standings[match.team2]!['pts'] = standings[match.team2]!['pts']! + 1;
        standings[match.team1]!['e'] = standings[match.team1]!['e']! + 1;
        standings[match.team2]!['e'] = standings[match.team2]!['e']! + 1;
      } else {
        standings[match.team2]!['pts'] = standings[match.team2]!['pts']! + 3;
        standings[match.team2]!['v'] = standings[match.team2]!['v']! + 1;
        standings[match.team1]!['d'] = standings[match.team1]!['d']! + 1;
      }
    }

    final group = _groups.firstWhere(
      (g) => g.name == groupName,
      orElse: () => Group(name: groupName, teams: []),
    );
    for (final team in group.teams) {
      addTeam(team);
    }

    final list = standings.entries.map((e) {
      final team = _teams.firstWhere(
        (t) => t.name == e.key || t.nameNormalised == e.key,
        orElse: () => Team(
          name: e.key,
          continent: '',
          flagIcon: '🏳️',
          fifaCode: '',
          group: groupName,
          confed: '',
        ),
      );
      return {
        'team': e.key,
        'flag': team.flagIcon,
        ...e.value,
        'sg': (e.value['gp']! - e.value['gc']!),
      };
    }).toList();

    list.sort((a, b) {
      int cmp = (b['pts'] as int).compareTo(a['pts'] as int);
      if (cmp != 0) return cmp;
      cmp = (b['sg'] as int).compareTo(a['sg'] as int);
      if (cmp != 0) return cmp;
      return (b['gp'] as int).compareTo(a['gp'] as int);
    });

    return list;
  }
}
