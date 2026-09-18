import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../services/openfootball_json_service.dart';
import '../utils/bracket_code_resolver.dart';
import '../utils/standings_calculator.dart';

const _weightedScores = [
  [1, 0], [0, 1], [2, 1], [1, 2], [2, 0], [0, 2], [1, 1],
  [3, 1], [1, 3], [3, 0], [0, 3], [2, 2], [3, 2], [2, 3],
  [4, 0], [0, 4], [4, 1], [1, 4],
];
const _weights = [12, 12, 9, 9, 8, 8, 7, 5, 5, 4, 4, 3, 2, 2, 1, 1, 1, 1];
const _weightsNoTie = [13, 13, 10, 10, 9, 9, 6, 6, 5, 5, 3, 3, 1, 1, 1, 1];

class SimulatorProvider extends ChangeNotifier {
  final OpenFootballJsonService _api = OpenFootballJsonService();

  List<Match> _matches = [];
  final Map<String, List<int>> _results = {}; // matchKey -> [s1, s2]

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  bool get isLoaded => _matches.isNotEmpty;

  List<Match> get allMatches => _matches;

  List<Match> get groupMatches =>
      _matches.where((m) => m.group != null).toList();

  List<Match> get knockoutMatches =>
      _matches.where((m) => m.group == null).toList();

  List<Match> get roundOf32 =>
      _matches.where((m) => m.round == 'Round of 32').toList();

  List<Match> get roundOf16 =>
      _matches.where((m) => m.round == 'Round of 16').toList();

  List<Match> get quarterFinals =>
      _matches.where((m) => m.round == 'Quarter-final').toList();

  List<Match> get semiFinals =>
      _matches.where((m) => m.round == 'Semi-final').toList();

  List<Match> get thirdPlace =>
      _matches.where((m) => m.round == 'Match for third place').toList();

  List<Match> get final_ =>
      _matches.where((m) => m.round == 'Final').toList();

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_matches.isNotEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _matches = await _api.fetchMatches(2026);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  // ── Results ───────────────────────────────────────────────────────────────

  List<int>? getResult(String matchKey) => _results[matchKey];

  bool hasResult(String matchKey) => _results.containsKey(matchKey);

  void setResult(Match match, int s1, int s2) {
    _results[match.matchKey] = [s1, s2];
    notifyListeners();
  }

  void removeResult(String matchKey) {
    _results.remove(matchKey);
    notifyListeners();
  }

  void resetAll() {
    _results.clear();
    notifyListeners();
  }

  void resetGroups() {
    for (final m in groupMatches) {
      _results.remove(m.matchKey);
    }
    notifyListeners();
  }

  // ── Auto-Simulate ─────────────────────────────────────────────────────────

  void autoSimulateGroups() {
    for (final m in groupMatches) {
      if (!hasResult(m.matchKey)) {
        _results[m.matchKey] = _randomScore();
      }
    }
    notifyListeners();
  }

  void autoSimulateAllGroups() {
    for (final m in groupMatches) {
      _results[m.matchKey] = _randomScore();
    }
    notifyListeners();
  }

  void autoSimulateKnockout() {
    final rounds = [
      roundOf32, roundOf16, quarterFinals, semiFinals, thirdPlace, final_
    ];
    for (final round in rounds) {
      for (final m in round) {
        if (!hasResult(m.matchKey)) {
          _results[m.matchKey] = _randomScore(canDraw: false);
        }
      }
    }
    notifyListeners();
  }

  void autoSimulateAll() {
    autoSimulateAllGroups();
    for (final m in knockoutMatches) {
      _results[m.matchKey] = _randomScore(canDraw: false);
    }
    notifyListeners();
  }

  // ── Standings ─────────────────────────────────────────────────────────────

  /// Returns group standings: groupName -> sorted list of team stats
  Map<String, List<Map<String, dynamic>>> computeAllStandings() {
    final Map<String, List<Match>> byGroup = {};
    for (final m in groupMatches) {
      byGroup.putIfAbsent(m.group!, () => []).add(m);
    }

    return {
      for (final entry in byGroup.entries)
        entry.key: computeStandings(
          entry.value,
          scoreOf: (m) => _results[m.matchKey],
          // Times aparecem na tabela com 0 mesmo antes de jogar.
          knownTeams: {
            for (final m in entry.value) ...[m.team1, m.team2],
          },
        ),
    };
  }

  // ── Team Code Resolution ──────────────────────────────────────────────────

  /// Empate no chaveamento simulado (sem pênaltis modelados) sempre favorece
  /// o time 1 — mesmo critério do código original.
  late final BracketCodeResolver _resolver = BracketCodeResolver(
    matchByNum: _matchByNum,
    resultOf: (m) => _results[m.matchKey],
    standingsByGroup: computeAllStandings,
    winnerIndex: (m, r) => r[0] >= r[1] ? 0 : 1,
    fallbackToTopWhenExhausted: true,
  );

  /// Resolves a bracket team code to an actual team name.
  /// - "1A" → 1st place Group A
  /// - "2B" → 2nd place Group B
  /// - "3A/B/C/D/F" → best 3rd-place from those groups
  /// - "W73" → winner of match 73
  /// - "L101" → loser of match 101
  String resolveCode(String code) => _resolver.resolve(code);

  Match? _matchByNum(int num) {
    try {
      return _matches.firstWhere((m) => m.num == num);
    } catch (_) {
      return null;
    }
  }

  /// Clears the 3rd-place assignment cache (call before resolving bracket).
  void reset3rdAssignment() => _resolver.resetThirdPlaceAssignment();

  // ── Projected champion & results ──────────────────────────────────────────

  String? get projectedChampion {
    if (final_.isEmpty) return null;
    final f = final_.first;
    final result = _results[f.matchKey];
    if (result == null) return null;
    final t1 = resolveCode(f.team1);
    final t2 = resolveCode(f.team2);
    return result[0] >= result[1] ? t1 : t2;
  }

  int get simulatedGroupMatches =>
      groupMatches.where((m) => hasResult(m.matchKey)).length;

  int get totalGroupMatches => groupMatches.length;

  bool get allGroupsSimulated =>
      simulatedGroupMatches == totalGroupMatches;

  /// Public single-match random score (used by UI buttons)
  List<int> autoSimulateKnockoutMatch({bool canDraw = false}) =>
      _randomScore(canDraw: canDraw);

  // ── Random Score ──────────────────────────────────────────────────────────

  List<int> _randomScore({bool canDraw = true}) {
    final scores = canDraw
        ? _weightedScores
        : _weightedScores.where((s) => s[0] != s[1]).toList();
    final weights = canDraw ? _weights : _weightsNoTie;

    final total = weights.reduce((a, b) => a + b);
    int r = Random().nextInt(total);
    int cumulative = 0;
    for (int i = 0; i < scores.length; i++) {
      cumulative += weights[i];
      if (r < cumulative) return [...scores[i]];
    }
    return [1, 0];
  }
}
