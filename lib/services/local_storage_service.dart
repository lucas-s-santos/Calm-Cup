import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_result.dart';

class LocalStorageService {
  static const _prefix = 'result_';
  static const _matchesCacheKey = 'matches_2026_json';

  Future<void> saveMatchesCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_matchesCacheKey, rawJson);
  }

  Future<String?> loadMatchesCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_matchesCacheKey);
  }

  Future<void> saveResult(String matchKey, int score1, int score2) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + matchKey, '$score1:$score2');
  }

  Future<LocalResult?> getResult(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + matchKey);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    return LocalResult(
      matchKey: matchKey,
      score1: int.tryParse(parts[0]) ?? 0,
      score2: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<Map<String, LocalResult>> getAllResults() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final Map<String, LocalResult> results = {};
    for (final key in keys) {
      final matchKey = key.substring(_prefix.length);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final parts = raw.split(':');
      if (parts.length != 2) continue;
      results[matchKey] = LocalResult(
        matchKey: matchKey,
        score1: int.tryParse(parts[0]) ?? 0,
        score2: int.tryParse(parts[1]) ?? 0,
      );
    }
    return results;
  }

  Future<void> deleteResult(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + matchKey);
  }
}
