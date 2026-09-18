import 'package:flutter/foundation.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/match.dart';
import '../services/openfootball_json_service.dart';
import '../services/openfootball_text_service.dart';

/// Uma partida de qualquer competição do catálogo já rotulada com de onde
/// ela vem — é o que permite misturar Brasileirão, Champions, ligas etc. numa
/// lista só sem perder a informação de qual campeonato é qual.
class LabeledMatch {
  final Match match;
  final String competitionName;
  final String competitionEmoji;
  final String? competitionId;

  const LabeledMatch({
    required this.match,
    required this.competitionName,
    required this.competitionEmoji,
    this.competitionId,
  });
}

/// Agrega partidas de TODAS as competições do catálogo (Brasileirão, Champions
/// League, Libertadores, Euro, Copa América, ligas europeias...) pra
/// alimentar o "Jogos de Hoje"/"Próximos Jogos" da home com uma lista única,
/// ordenada por horário. A Copa do Mundo 2026 não entra aqui — ela já tem seu
/// próprio provider com placar ao vivo; a home mistura os dois na hora de
/// montar a lista final.
///
/// Busca a temporada atual (`editions.first`) de cada competição uma vez só
/// e guarda todas as partidas (não só as de hoje) em cache, pra também servir
/// "Próximos Jogos" sem precisar refazer o fetch. Falha de uma competição não
/// derruba as outras — mesma filosofia tolerante do parser de texto.
class TodayMatchesProvider extends ChangeNotifier {
  final OpenFootballJsonService _jsonApi = OpenFootballJsonService();
  final OpenFootballTextService _textApi = OpenFootballTextService();

  bool _loading = false;
  bool get loading => _loading;
  bool _loaded = false;
  bool get loaded => _loaded;

  List<LabeledMatch> _catalogMatches = [];

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loading = true;
    notifyListeners();

    final perCompetition = await Future.wait(
      competitionsCatalog.map(_fetchCompetition),
    );
    _catalogMatches = perCompetition.expand((l) => l).toList();

    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  Future<List<LabeledMatch>> _fetchCompetition(Competition c) async {
    try {
      final edition = c.editions.first;
      final raw = await _jsonApi.fetchMatchesRawFromUrl(edition.matchesUrl);
      final matches = edition.sourceFormat == DataSourceFormat.text
          ? _textApi.parseMatches(raw, edition.textDialect!)
          : _jsonApi.parseMatchesFromRaw(raw);
      return matches
          .map((m) => LabeledMatch(
                match: m,
                competitionName: c.name,
                competitionEmoji: c.emoji,
                competitionId: c.id,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<LabeledMatch> today() {
    final todayStr = _dateStr(DateTime.now());
    return _catalogMatches.where((lm) => lm.match.date == todayStr).toList();
  }

  List<LabeledMatch> nextDays({int days = 4}) {
    final now = DateTime.now();
    final limit = now.add(Duration(days: days));
    return _catalogMatches
        .where((lm) =>
            lm.match.dateTime.isAfter(now) && lm.match.dateTime.isBefore(limit))
        .toList();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// `true` quando a edição atual do catálogo (`Competition.editions.first`)
  /// dessa competição ainda tem pelo menos um jogo agendado no futuro — ou
  /// seja, a temporada está em andamento. `false` quando todos os jogos já
  /// aconteceram (temporada encerrada) — usado pra decidir Campeonatos
  /// (só o que está rolando) vs História (o que já acabou). Enquanto os
  /// dados ainda não carregaram, assume `false` (trata como "ainda não sei
  /// que está rolando" até confirmar).
  bool isCurrentlyRunning(String competitionId) {
    if (!_loaded) return false;
    final now = DateTime.now();
    return _catalogMatches.any(
        (lm) => lm.competitionId == competitionId && lm.match.dateTime.isAfter(now));
  }
}
