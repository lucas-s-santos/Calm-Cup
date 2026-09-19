import 'package:flutter/foundation.dart';
import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import '../models/match.dart';
import '../services/local_storage_service.dart';
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
  final LocalStorageService _local = LocalStorageService();

  bool _loading = false;
  bool get loading => _loading;
  bool _loaded = false;
  bool get loaded => _loaded;

  bool _usedCache = false;
  int _failedCompetitions = 0;

  /// `true` quando pelo menos uma competição não pôde ser atualizada e
  /// entrou com dados do cache offline — a home avisa que a lista pode estar
  /// desatualizada.
  bool get usedCache => _usedCache;

  /// `true` quando *nenhuma* competição carregou (nem da rede nem do cache):
  /// a lista vazia é falha de conexão, não "não há jogos hoje". Sem isso a
  /// home dizia "nenhum jogo" para quem estava simplesmente offline.
  bool get allFailed =>
      _loaded && _failedCompetitions == competitionsCatalog.length;

  List<LabeledMatch> _catalogMatches = [];

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loading = true;
    _usedCache = false;
    _failedCompetitions = 0;
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
    final edition = c.editions.first;
    final url = edition.matchesUrl;

    List<LabeledMatch> label(String raw) {
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
    }

    try {
      final raw = await _jsonApi.fetchMatchesRawFromUrl(url);
      await _local.saveRawByUrl(url, raw);
      return label(raw);
    } catch (_) {
      // Offline (ou competição fora do ar): usa os últimos dados baixados
      // dessa competição em vez de sumir com ela da home. Quem falhou *e*
      // não tem cache continua saindo em silêncio — uma competição não
      // derruba as outras dez.
      try {
        final cached = await _local.loadRawByUrl(url);
        if (cached != null) {
          _usedCache = true;
          return label(cached);
        }
      } catch (_) {}
      _failedCompetitions++;
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
