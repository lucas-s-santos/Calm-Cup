import 'package:shared_preferences/shared_preferences.dart';
import '../models/prediction.dart';
import '../models/match.dart';

class PredictionService {
  static const _prefix = 'pred_';

  Future<void> save(Prediction p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + p.matchKey, '${p.score1}:${p.score2}');
  }

  Future<void> delete(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + matchKey);
  }

  Future<Map<String, Prediction>> loadAll(List<Match> matches) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, Prediction>{};
    for (final match in matches) {
      final raw = prefs.getString(_prefix + match.matchKey);
      if (raw == null) continue;
      final parts = raw.split(':');
      if (parts.length != 2) continue;
      result[match.matchKey] = Prediction(
        matchKey: match.matchKey,
        team1: match.team1,
        team2: match.team2,
        date: match.date,
        score1: int.tryParse(parts[0]) ?? 0,
        score2: int.tryParse(parts[1]) ?? 0,
      );
    }
    return result;
  }
}
