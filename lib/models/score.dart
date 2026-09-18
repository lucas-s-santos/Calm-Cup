import '../utils/json_parse.dart';

class Score {
  final List<int> ft;
  final List<int>? ht;
  final List<int>? et;
  final List<int>? p;

  const Score({required this.ft, this.ht, this.et, this.p});

  /// Aceita tanto o formato padrão `{"ft": [...], "ht": [...]}` quanto um
  /// array simples `[gols1, gols2]` — jogos terminados 0x0 em algumas ligas
  /// do football.json (ex.: Premier League, Serie A) vêm assim, em vez do
  /// objeto completo (bug de geração dos dados na fonte, confirmado contra
  /// várias ligas 2025/26 — não é caso raro, dezenas de jogos por liga).
  factory Score.fromJson(dynamic json) {
    List<int> parseList(dynamic val) {
      if (val == null) return [];
      return (val as List)
          .map(asIntOrNull)
          .whereType<int>()
          .toList();
    }

    if (json is List) {
      return Score(ft: parseList(json));
    }

    final map = json as Map<String, dynamic>;
    return Score(
      ft: parseList(map['ft']),
      ht: map['ht'] != null ? parseList(map['ht']) : null,
      et: map['et'] != null ? parseList(map['et']) : null,
      p: map['p'] != null ? parseList(map['p']) : null,
    );
  }

  String get displayScore =>
      ft.length >= 2 ? '${ft[0]} x ${ft[1]}' : '- x -';

  bool get hasResult => ft.length == 2;
}
