import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/ranking_entry.dart';
import 'package:calmcup/providers/ranking_provider.dart';
import 'package:calmcup/services/firebase_ranking_service.dart';

/// Fake em memória, sem tocar nos plugins reais do Firebase (que não rodam
/// em `flutter test`) — só sobrescreve os métodos que o `RankingProvider`
/// realmente chama.
class _FakeRankingService extends FirebaseRankingService {
  final Map<String, String> nicknames = {};
  final Map<String, Map<String, RankingEntry>> rankings = {};
  int pushCount = 0;

  @override
  Future<String> ensureSignedIn() async => 'fake-uid';

  @override
  Future<String?> fetchNickname(String uid) async => nicknames[uid];

  @override
  Future<void> setNickname(String uid, String nickname) async {
    nicknames[uid] = nickname;
  }

  @override
  Future<void> pushScore({
    required String competitionId,
    required String uid,
    required String nickname,
    required int points,
    required int predictionsMade,
    required String editionId,
  }) async {
    pushCount++;
    rankings.putIfAbsent(competitionId, () => {})[uid] = RankingEntry(
      uid: uid,
      nickname: nickname,
      points: points,
      predictionsMade: predictionsMade,
      editionId: editionId,
    );
  }

  @override
  Future<List<RankingEntry>> topEntries(String competitionId,
      {int limit = 50}) async {
    final entries = rankings[competitionId]?.values.toList() ?? [];
    entries.sort((a, b) => b.points.compareTo(a.points));
    return entries.take(limit).toList();
  }
}

class _ThrowingRankingService extends FirebaseRankingService {
  @override
  Future<String> ensureSignedIn() async =>
      throw StateError('sem Firebase configurado');
}

void main() {
  group('RankingProvider', () {
    test('init faz sign-in e carrega apelido já salvo', () async {
      final service = _FakeRankingService()..nicknames['fake-uid'] = 'Zizou';
      final provider = RankingProvider(service: service);

      await provider.init();

      expect(provider.unavailable, isFalse);
      expect(provider.initialized, isTrue);
      expect(provider.nickname, 'Zizou');
      expect(provider.hasNickname, isTrue);
      expect(provider.myUid, 'fake-uid');
    });

    test('init marca unavailable quando o sign-in falha (ex.: Windows sem Firebase)',
        () async {
      final provider = RankingProvider(service: _ThrowingRankingService());

      await provider.init();

      expect(provider.unavailable, isTrue);
    });

    test('syncIfChanged não envia nada sem apelido definido', () async {
      final service = _FakeRankingService();
      final provider = RankingProvider(service: service);
      await provider.init();

      await provider.syncIfChanged('brasileirao', '2026', 10, 5);

      expect(service.pushCount, 0);
    });

    test('syncIfChanged envia uma vez e não repete o mesmo total', () async {
      final service = _FakeRankingService();
      final provider = RankingProvider(service: service);
      await provider.init();
      await provider.setNickname('Craque');

      await provider.syncIfChanged('brasileirao', '2026', 10, 5);
      await provider.syncIfChanged('brasileirao', '2026', 10, 5);

      expect(service.pushCount, 1);
    });

    test('syncIfChanged envia de novo quando o total muda', () async {
      final service = _FakeRankingService();
      final provider = RankingProvider(service: service);
      await provider.init();
      await provider.setNickname('Craque');

      await provider.syncIfChanged('brasileirao', '2026', 10, 5);
      await provider.syncIfChanged('brasileirao', '2026', 13, 6);

      expect(service.pushCount, 2);
      expect(provider.topEntries('brasileirao').first.points, 13);
    });

    test('syncIfChanged nunca mistura pontos entre competições diferentes',
        () async {
      final service = _FakeRankingService();
      final provider = RankingProvider(service: service);
      await provider.init();
      await provider.setNickname('Craque');

      await provider.syncIfChanged('brasileirao', '2026', 9, 3);
      await provider.syncIfChanged('libertadores', '2026', 21, 7);

      expect(service.pushCount, 2);
      expect(provider.topEntries('brasileirao').single.points, 9);
      expect(provider.topEntries('libertadores').single.points, 21);
    });
  });
}
