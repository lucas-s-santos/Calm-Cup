class Prediction {
  final String matchKey;
  final String team1;
  final String team2;
  final String date;
  final int score1;
  final int score2;

  const Prediction({
    required this.matchKey,
    required this.team1,
    required this.team2,
    required this.date,
    required this.score1,
    required this.score2,
  });

  String get displayScore => '$score1 × $score2';

  // -1 = jogo não aconteceu, 0 = errou, 1 = acertou resultado, 3 = placar exato
  int calculatePoints(int? actual1, int? actual2) {
    if (actual1 == null || actual2 == null) return -1;
    if (score1 == actual1 && score2 == actual2) return 3;
    final pw = score1 > score2 ? 1 : (score1 < score2 ? -1 : 0);
    final aw = actual1 > actual2 ? 1 : (actual1 < actual2 ? -1 : 0);
    return pw == aw ? 1 : 0;
  }
}
