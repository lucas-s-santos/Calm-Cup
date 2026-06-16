import 'score.dart';
import 'goal.dart';
import '../utils/json_parse.dart';

class Match {
  final String round;
  final String date;
  final String time;
  final String team1;
  final String team2;
  final String? group;
  final String ground;
  final int? num;
  final Score? score;
  final List<Goal> goals1;
  final List<Goal> goals2;

  const Match({
    required this.round,
    required this.date,
    required this.time,
    required this.team1,
    required this.team2,
    this.group,
    required this.ground,
    this.num,
    this.score,
    this.goals1 = const [],
    this.goals2 = const [],
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    List<Goal> parseGoals(dynamic list) {
      if (list == null) return [];
      return (list as List).map((g) => Goal.fromJson(g as Map<String, dynamic>)).toList();
    }

    return Match(
      round: json['round'] as String,
      date: json['date'] as String,
      time: (json['time'] as String?) ?? '',
      team1: json['team1'] as String,
      team2: json['team2'] as String,
      group: json['group'] as String?,
      ground: json['ground'] as String,
      num: asIntOrNull(json['num']),
      score: json['score'] != null
          ? Score.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      goals1: parseGoals(json['goals1']),
      goals2: parseGoals(json['goals2']),
    );
  }

  /// Cópia da partida com um placar diferente (usado para sobrepor o placar
  /// da fonte secundária mantendo todo o resto do openfootball).
  Match copyWith({Score? score}) => Match(
        round: round,
        date: date,
        time: time,
        team1: team1,
        team2: team2,
        group: group,
        ground: ground,
        num: num,
        score: score ?? this.score,
        goals1: goals1,
        goals2: goals2,
      );

  bool get isGroupStage => group != null;

  bool get hasResult => score?.hasResult == true;

  /// Instante absoluto do início do jogo.
  ///
  /// Aceita tanto o formato antigo `"HH:MM"` quanto o formato da Copa 2026
  /// `"HH:MM UTC-6"` / `"HH:MM UTC+2"`, em que o horário é a hora local do
  /// estádio seguida do seu fuso. Quando há fuso, retorna o instante em UTC
  /// (comparável com `DateTime.now()`); sem fuso, interpreta como hora local.
  DateTime get dateTime {
    final d = DateTime.parse(date);
    if (time.isEmpty) return d;

    final spaceIdx = time.indexOf(' ');
    final clock = spaceIdx == -1 ? time : time.substring(0, spaceIdx);
    final hm = clock.split(':');
    final hour = hm.isNotEmpty ? (int.tryParse(hm[0]) ?? 0) : 0;
    final minute = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;

    final offset =
        spaceIdx == -1 ? null : _parseUtcOffset(time.substring(spaceIdx + 1));

    if (offset != null) {
      // Hora local do estádio + fuso → instante absoluto (UTC).
      return DateTime.utc(d.year, d.month, d.day, hour, minute)
          .subtract(offset);
    }

    // Sem fuso: interpreta como horário local do dispositivo (formato antigo).
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  /// Horário do jogo já convertido para o fuso do dispositivo, ex.: `"16:00"`.
  /// Vazio quando a fonte não informa horário.
  String get localTimeLabel {
    if (time.isEmpty) return '';
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Converte "UTC-6", "UTC+2", "UTC-3:30" em Duration. Retorna null se a
  // string não for um deslocamento de UTC reconhecido.
  static Duration? _parseUtcOffset(String raw) {
    final s = raw.trim();
    if (!s.startsWith('UTC')) return null;
    var rest = s.substring(3).trim();
    if (rest.isEmpty) return Duration.zero;
    final sign = rest.startsWith('-') ? -1 : 1;
    if (rest.startsWith('+') || rest.startsWith('-')) {
      rest = rest.substring(1);
    }
    final parts = rest.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return Duration(hours: sign * h, minutes: sign * m);
  }

  String get matchKey => '${date}_${team1}_$team2'.replaceAll(' ', '_');
}
