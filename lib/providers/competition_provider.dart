import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/competition.dart';
import '../services/local_storage_service.dart';
import '../services/openfootball_json_service.dart';
import '../services/openfootball_text_service.dart';
import '../utils/standings_calculator.dart';

/// Provider genérico pra qualquer competição do catálogo (Eurocopa, ligas
/// europeias, Champions League...). A Copa do Mundo 2026 continua com seu
/// próprio `Copa2026Provider` — esta classe é só pra tudo que chegou depois.
///
/// Sem overlay de placar ao vivo e sem edição manual de resultado: essas
/// competições são só leitura (temporadas em andamento ou já encerradas).
class CompetitionProvider extends ChangeNotifier {
  final OpenFootballJsonService _jsonApi = OpenFootballJsonService();
  final OpenFootballTextService _textApi = OpenFootballTextService();
  final LocalStorageService _local = LocalStorageService();

  final Competition competition;
  CompetitionEdition _edition;

  CompetitionProvider(this.competition)
      : _edition = competition.editions.first {
    load();
  }

  CompetitionEdition get edition => _edition;

  List<Match> _matches = [];
  List<Match> get matches => _matches;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _fromCache = false;

  /// `true` quando as partidas exibidas vieram do cache offline porque a rede
  /// falhou — a tela avisa que os dados podem estar desatualizados em vez de
  /// deixar a pessoa achar que são ao vivo.
  bool get fromCache => _fromCache;

  Future<void> selectEdition(CompetitionEdition newEdition) async {
    if (newEdition.id == _edition.id) return;
    _edition = newEdition;
    _matches = [];
    await load();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final url = _edition.matchesUrl;
    try {
      final raw = await _jsonApi.fetchMatchesRawFromUrl(url);
      await _local.saveRawByUrl(url, raw);
      _matches = _parse(raw);
      _fromCache = false;
    } catch (e) {
      // Mesma estratégia rede → cache offline que a Copa 2026 já usava: sem
      // internet a competição continua abrindo com os últimos dados vistos,
      // sinalizados como desatualizados em vez de virarem tela de erro.
      final cached = await _local.loadRawByUrl(url);
      if (cached != null) {
        try {
          _matches = _parse(cached);
          _fromCache = true;
        } catch (_) {
          _error = e.toString();
        }
      } else {
        _error = e.toString();
      }
    }

    _loading = false;
    notifyListeners();
  }

  List<Match> _parse(String raw) =>
      _edition.sourceFormat == DataSourceFormat.text
          ? _textApi.parseMatches(raw, _edition.textDialect!)
          : _jsonApi.parseMatchesFromRaw(raw);

  /// Partidas agrupadas por rodada e ordenadas cronologicamente (pela data
  /// do primeiro jogo de cada rodada) — mesma ideia do
  /// `HistoryProvider.groupByRound`, mas ordenada em vez de na ordem de
  /// chegada do JSON.
  List<MapEntry<String, List<Match>>> get roundsSorted {
    final Map<String, List<Match>> byRound = {};
    for (final m in _matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final entries = byRound.entries.toList()
      ..sort((a, b) => _earliestDate(a.value).compareTo(_earliestDate(b.value)));
    return entries;
  }

  String _earliestDate(List<Match> matches) =>
      matches.map((m) => m.date).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);

  /// Nomes de grupo distintos (só relevante pra `groupsAndKnockout`), na
  /// ordem alfabética ("Group A", "Group B"...).
  List<String> get groupNames {
    final names =
        _matches.map((m) => m.group).whereType<String>().toSet().toList();
    names.sort();
    return names;
  }

  /// Classificação de um grupo (`groupsAndKnockout`) ou a tabela única da
  /// competição (`league` — inclusive a fase de liga da Champions League,
  /// cujo mata-mata fica de fora da tabela).
  List<Map<String, dynamic>> standingsFor({String? group}) {
    final relevant = competition.format == CompetitionFormat.groupsAndKnockout
        ? _matches.where((m) => m.group == group)
        : _matches.where((m) => countsTowardLeagueTable(m.round));

    return computeStandings(
      relevant.toList(),
      scoreOf: (m) =>
          m.score?.hasResult == true ? [m.score!.ft[0], m.score!.ft[1]] : null,
    );
  }

  // Domésticas: toda rodada é "Matchday N", sempre conta. Champions League:
  // a fase de liga é "League, Matchday N" (conta); os playoffs de acesso ao
  // mata-mata ("Playoffs, Matchday N" — sim, também tem "Matchday" no nome)
  // e as fases finais ("Finals, ...") não contam na tabela. Público (não
  // `_privado`) só pra ser testável direto, sem precisar montar um provider
  // inteiro com fetch de rede.
  static bool countsTowardLeagueTable(String round) =>
      !round.startsWith('Playoffs') && !round.startsWith('Finals');
}
