import 'package:flutter/foundation.dart';
import '../models/prediction.dart';
import '../models/match.dart';
import '../services/prediction_service.dart';

class BolaoProvider extends ChangeNotifier {
  final _service = PredictionService();
  final Map<String, Prediction> _predictions = {};
  // Partidas cujo palpite salvo já foi lido do storage — permite chamar
  // `load` de novo pra cada campeonato escolhido no Bolão sem re-ler do
  // disco nem perder o que já foi carregado de outro campeonato (o mapa de
  // palpites é global, mas cada partida só pertence a uma competição — as
  // chaves não colidem entre competições diferentes).
  final Set<String> _loadedMatchKeys = {};

  Map<String, Prediction> get predictions => Map.unmodifiable(_predictions);

  /// `true` quando todas as partidas da lista já têm seu palpite (se algum)
  /// carregado do storage — usado pra decidir se mostra o spinner na aba
  /// "Meus Palpites" do campeonato selecionado no momento.
  bool isLoaded(List<Match> matches) =>
      matches.every((m) => _loadedMatchKeys.contains(m.matchKey));

  int get totalPoints {
    int pts = 0;
    for (final p in _predictions.values) {
      final v = p.calculatePoints(null, null);
      if (v > 0) pts += v;
    }
    return pts;
  }

  Future<void> load(List<Match> matches) async {
    final toFetch =
        matches.where((m) => !_loadedMatchKeys.contains(m.matchKey)).toList();
    if (toFetch.isEmpty) return;
    _predictions.addAll(await _service.loadAll(toFetch));
    _loadedMatchKeys.addAll(toFetch.map((m) => m.matchKey));
    notifyListeners();
  }

  // Recalcula pontuação usando resultados reais das partidas
  int computeTotal(List<Match> matches) {
    int pts = 0;
    for (final match in matches) {
      final pred = _predictions[match.matchKey];
      if (pred == null) continue;
      final score = match.score;
      if (score == null || !score.hasResult) continue;
      final p = pred.calculatePoints(score.ft[0], score.ft[1]);
      if (p > 0) pts += p;
    }
    return pts;
  }

  Future<void> savePrediction(Match match, int s1, int s2) async {
    final p = Prediction(
      matchKey: match.matchKey,
      team1: match.team1,
      team2: match.team2,
      date: match.date,
      score1: s1,
      score2: s2,
    );
    await _service.save(p);
    _predictions[match.matchKey] = p;
    notifyListeners();
  }

  Future<void> deletePrediction(String matchKey) async {
    await _service.delete(matchKey);
    _predictions.remove(matchKey);
    notifyListeners();
  }
}
