import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/team.dart';
import '../models/stadium.dart';
import '../models/group.dart';

class WorldCupApiService {
  static const _base =
      'https://raw.githubusercontent.com/openfootball/worldcup.json/master';

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
}
