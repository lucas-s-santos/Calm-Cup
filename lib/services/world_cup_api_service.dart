import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/team.dart';
import '../models/stadium.dart';
import '../models/group.dart';
import '../models/score.dart';

class WorldCupApiService {
  static const _base =
      'https://raw.githubusercontent.com/openfootball/worldcup.json/master';

  // Fonte secundária de placares (camada sobreposta ao openfootball).
  static const _liveBase =
      'https://raw.githubusercontent.com/rezarahiminia/worldcup2026/main';

  // Apelidos: nome da seleção no rezarahiminia -> nome no openfootball.
  static const Map<String, String> _liveTeamAliases = {
    'Bosnia and Herzegovina': 'Bosnia & Herzegovina',
    'Democratic Republic of the Congo': 'DR Congo',
    'United States': 'USA',
  };

  static const List<int> historicalYears = [
    1930, 1934, 1938, 1950, 1954, 1958, 1962, 1966, 1970, 1974,
    1978, 1982, 1986, 1990, 1994, 1998, 2002, 2006, 2010, 2014,
    2018, 2022,
  ];

  Future<String> fetchMatchesRaw(int year) async {
    final url = Uri.parse('$_base/$year/worldcup.json');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) throw Exception('NOT_FOUND');
    if (response.statusCode != 200) throw Exception('Erro ao carregar Copa $year');
    return response.body;
  }

  List<Match> parseMatchesFromRaw(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final matches = data['matches'] as List;
    return matches.map((m) => Match.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<List<Match>> fetchMatches(int year) async {
    final raw = await fetchMatchesRaw(year);
    return parseMatchesFromRaw(raw);
  }

  Future<List<Team>> fetchTeams2026() async {
    final url = Uri.parse('$_base/2026/worldcup.teams.json');
    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Erro ao carregar seleções');
    final data = json.decode(response.body) as List;
    return data.map((t) => Team.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<List<Stadium>> fetchStadiums2026() async {
    final url = Uri.parse('$_base/2026/worldcup.stadiums.json');
    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Erro ao carregar estádios');
    final data = json.decode(response.body) as Map<String, dynamic>;
    final stadiums = data['stadiums'] as List;
    return stadiums.map((s) => Stadium.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<List<Group>> fetchGroups(int year) async {
    final url = Uri.parse('$_base/$year/worldcup.groups.json');
    final response = await http.get(url);
    if (response.statusCode != 200) return [];
    final data = json.decode(response.body) as Map<String, dynamic>;
    final groups = data['groups'] as List?;
    if (groups == null) return [];
    return groups.map((g) => Group.fromJson(g as Map<String, dynamic>)).toList();
  }

  // Extrai grupos diretamente das partidas para anos sem arquivo de grupos
  List<Group> extractGroupsFromMatches(List<Match> matches) {
    final Map<String, List<String>> groupMap = {};
    for (final m in matches) {
      if (m.group == null) continue;
      groupMap.putIfAbsent(m.group!, () => []);
      if (!groupMap[m.group!]!.contains(m.team1)) groupMap[m.group!]!.add(m.team1);
      if (!groupMap[m.group!]!.contains(m.team2)) groupMap[m.group!]!.add(m.team2);
    }
    final sorted = groupMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => Group(name: e.key, teams: e.value)).toList();
  }

  // ── Placares ao vivo (fonte secundária: rezarahiminia/worldcup2026) ──────────

  /// Busca os placares de jogos já iniciados/finalizados e retorna um mapa
  /// `matchKey -> Score` na MESMA orientação usada pelo openfootball.
  /// Lança em caso de falha de rede — o chamador trata como não-fatal.
  Future<Map<String, Score>> fetchLiveScores2026() async {
    final responses = await Future.wait([
      http.get(Uri.parse('$_liveBase/football.teams.json'))
          .timeout(const Duration(seconds: 10)),
      http.get(Uri.parse('$_liveBase/football.matches.json'))
          .timeout(const Duration(seconds: 10)),
    ]);
    if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
      throw Exception('Erro ao carregar placares ao vivo');
    }
    return parseLiveScores(responses[0].body, responses[1].body);
  }

  /// Converte os JSONs (times + jogos) da fonte secundária em `matchKey -> Score`.
  /// Só inclui jogos com placar real (finalizados ou em andamento); ignora os
  /// que ainda não começaram (evita "0 x 0" falso).
  Map<String, Score> parseLiveScores(String teamsRaw, String matchesRaw) {
    final idToName = <String, String>{};
    for (final t in (json.decode(teamsRaw) as List)) {
      final m = t as Map<String, dynamic>;
      final id = m['id']?.toString();
      final name = m['name_en'] as String?;
      if (id != null && name != null) {
        idToName[id] = _liveTeamAliases[name] ?? name;
      }
    }

    final result = <String, Score>{};
    for (final mm in (json.decode(matchesRaw) as List)) {
      final m = mm as Map<String, dynamic>;
      final finished = (m['finished']?.toString() ?? '').toUpperCase() == 'TRUE';
      final elapsed = (m['time_elapsed']?.toString() ?? '').toLowerCase();
      final started =
          elapsed.isNotEmpty && elapsed != 'notstarted' && elapsed != 'null';
      if (!finished && !started) continue; // sem placar real ainda

      final home = idToName[m['home_team_id']?.toString()];
      final away = idToName[m['away_team_id']?.toString()];
      final hs = int.tryParse(m['home_score']?.toString() ?? '');
      final as_ = int.tryParse(m['away_score']?.toString() ?? '');
      final date = _isoDateFromUs(m['local_date']?.toString());
      if (home == null || away == null || hs == null || as_ == null ||
          date == null) {
        continue;
      }

      // Guarda nas duas orientações p/ casar com team1/team2 do openfootball.
      result[_liveKey(date, home, away)] = Score(ft: [hs, as_]);
      result[_liveKey(date, away, home)] = Score(ft: [as_, hs]);
    }
    return result;
  }

  // Mesma convenção de Match.matchKey: 'data_time1_time2' sem espaços.
  String _liveKey(String date, String a, String b) =>
      '${date}_${a}_$b'.replaceAll(' ', '_');

  // "06/11/2026 13:00" (MM/DD/AAAA) -> "2026-06-11"
  String? _isoDateFromUs(String? raw) {
    if (raw == null) return null;
    final p = raw.split(' ').first.split('/');
    if (p.length != 3 || p[2].length != 4) return null;
    return '${p[2]}-${p[0].padLeft(2, '0')}-${p[1].padLeft(2, '0')}';
  }
}
