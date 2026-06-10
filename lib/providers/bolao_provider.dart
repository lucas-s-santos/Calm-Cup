import 'package:flutter/foundation.dart';
import '../models/prediction.dart';
import '../models/match.dart';
import '../services/prediction_service.dart';

class BolaoProvider extends ChangeNotifier {
  final _service = PredictionService();
  Map<String, Prediction> _predictions = {};
  bool _loaded = false;

  Map<String, Prediction> get predictions => Map.unmodifiable(_predictions);
  bool get loaded => _loaded;

  int get totalPoints {
    int pts = 0;
    for (final p in _predictions.values) {
      final v = p.calculatePoints(null, null);
      if (v > 0) pts += v;
    }
    return pts;
  }

  Future<void> load(List<Match> matches) async {
    if (_loaded) return;
    _predictions = await _service.loadAll(matches);
    _loaded = true;
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
