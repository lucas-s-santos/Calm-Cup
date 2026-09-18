/// Uma linha do ranking do Bolão de uma competição — sempre isolada por
/// `competitionId` no Firestore (`bolao_rankings/{competitionId}/entries`),
/// nunca somada entre campeonatos diferentes.
class RankingEntry {
  final String uid;
  final String nickname;
  final int points;
  final int predictionsMade;
  final String editionId;

  const RankingEntry({
    required this.uid,
    required this.nickname,
    required this.points,
    required this.predictionsMade,
    required this.editionId,
  });

  factory RankingEntry.fromMap(String uid, Map<String, dynamic> map) {
    return RankingEntry(
      uid: uid,
      nickname: (map['nickname'] as String?) ?? '???',
      points: (map['points'] as num?)?.toInt() ?? 0,
      predictionsMade: (map['predictionsMade'] as num?)?.toInt() ?? 0,
      editionId: (map['editionId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'nickname': nickname,
        'points': points,
        'predictionsMade': predictionsMade,
        'editionId': editionId,
      };
}
