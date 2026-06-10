import 'score.dart';
import 'goal.dart';

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
      num: json['num'] as int?,
      score: json['score'] != null
          ? Score.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      goals1: parseGoals(json['goals1']),
      goals2: parseGoals(json['goals2']),
    );
  }

  bool get isGroupStage => group != null;

  bool get hasResult => score?.hasResult == true;

  DateTime get dateTime {
    if (time.isEmpty) return DateTime.parse(date);
    final t = time.length == 5 ? '$time:00' : time;
    return DateTime.parse('${date}T$t');
  }

  String get matchKey => '${date}_${team1}_$team2'.replaceAll(' ', '_');
}
