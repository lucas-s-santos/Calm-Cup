import '../utils/json_parse.dart';

class Score {
  final List<int> ft;
  final List<int>? ht;
  final List<int>? et;
  final List<int>? p;

  const Score({required this.ft, this.ht, this.et, this.p});

  factory Score.fromJson(Map<String, dynamic> json) {
    List<int> parseList(dynamic val) {
      if (val == null) return [];
      return (val as List)
          .map(asIntOrNull)
          .whereType<int>()
          .toList();
    }

    return Score(
      ft: parseList(json['ft']),
      ht: json['ht'] != null ? parseList(json['ht']) : null,
      et: json['et'] != null ? parseList(json['et']) : null,
      p: json['p'] != null ? parseList(json['p']) : null,
    );
  }

  String get displayScore =>
      ft.length >= 2 ? '${ft[0]} x ${ft[1]}' : '- x -';

  bool get hasResult => ft.length == 2;
}
