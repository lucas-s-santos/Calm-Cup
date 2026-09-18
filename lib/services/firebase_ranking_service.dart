import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ranking_entry.dart';

/// Camada fina sobre Firebase Auth (anônimo) + Firestore, isolada num
/// serviço próprio pra poder ser trocada por um fake nos testes do
/// [RankingProvider] sem depender dos plugins reais (que não rodam em
/// `flutter test`).
///
/// Modelo de dados (cada competição isolada, nunca somada):
/// ```
/// bolao_users/{uid}                              -> { nickname, ... }
/// bolao_rankings/{competitionId}/entries/{uid}   -> { uid, nickname, points, ... }
/// ```
class FirebaseRankingService {
  FirebaseRankingService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _authOverride = auth,
        _dbOverride = db;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  // Getters (não finais avaliados no construtor) de propósito: em
  // plataformas sem `Firebase.initializeApp()` chamado (Windows, testes),
  // `FirebaseAuth.instance`/`FirebaseFirestore.instance` lançam na hora.
  // Adiar pra dentro de cada método garante que o erro só aparece quando um
  // método é de fato chamado — sempre dentro do try/catch do
  // `RankingProvider`, nunca no `create:` (lazy, mas ainda fora de
  // try/catch) do `ChangeNotifierProvider`.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final cred = await _auth.signInAnonymously();
    final uid = cred.user?.uid;
    if (uid == null) throw StateError('Falha ao autenticar anonimamente.');
    return uid;
  }

  Future<String?> fetchNickname(String uid) async {
    final doc = await _db.collection('bolao_users').doc(uid).get();
    return doc.data()?['nickname'] as String?;
  }

  Future<void> setNickname(String uid, String nickname) async {
    await _db.collection('bolao_users').doc(uid).set({
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pushScore({
    required String competitionId,
    required String uid,
    required String nickname,
    required int points,
    required int predictionsMade,
    required String editionId,
  }) async {
    await _db
        .collection('bolao_rankings')
        .doc(competitionId)
        .collection('entries')
        .doc(uid)
        .set({
      'uid': uid,
      'nickname': nickname,
      'points': points,
      'predictionsMade': predictionsMade,
      'editionId': editionId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<RankingEntry>> topEntries(String competitionId,
      {int limit = 50}) async {
    final snap = await _db
        .collection('bolao_rankings')
        .doc(competitionId)
        .collection('entries')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RankingEntry.fromMap(d.id, d.data())).toList();
  }
}
