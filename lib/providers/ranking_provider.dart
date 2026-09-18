import 'package:flutter/foundation.dart';
import '../models/ranking_entry.dart';
import '../services/firebase_ranking_service.dart';

/// Ranking do Bolão por competição — completamente separado do
/// `BolaoProvider` (que continua 100% local, sem rede). Só entra em jogo
/// quando a aba Ranking é aberta pela 1ª vez (`init()` preguiçoso): nunca
/// dispara Firebase pra quem nunca abre essa aba, e não quebra
/// `test/widget_test.dart` (montado sem Firebase inicializado).
///
/// `unavailable` cobre tanto falha de rede/config quanto plataformas sem
/// suporte (Windows não tem `Firebase.initializeApp()` chamado em
/// `main.dart` — `ensureSignedIn()` lança, cai no catch, marca
/// indisponível). O resto do Bolão continua funcionando normalmente.
class RankingProvider extends ChangeNotifier {
  RankingProvider({FirebaseRankingService? service})
      : _service = service ?? FirebaseRankingService();

  final FirebaseRankingService _service;

  bool _initStarted = false;
  bool get initialized => _initStarted;
  bool _unavailable = false;
  bool get unavailable => _unavailable;

  String? _uid;
  String? get myUid => _uid;

  String? _nickname;
  String? get nickname => _nickname;
  bool get hasNickname => _nickname != null && _nickname!.trim().isNotEmpty;

  bool _loadingRanking = false;
  bool get loadingRanking => _loadingRanking;

  final Map<String, List<RankingEntry>> _topByCompetition = {};
  List<RankingEntry> topEntries(String competitionId) =>
      _topByCompetition[competitionId] ?? const [];

  // Evita reenviar o mesmo total repetidamente a cada rebuild/resume.
  final Map<String, int> _lastSyncedPoints = {};

  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      _uid = await _service.ensureSignedIn();
      _nickname = await _service.fetchNickname(_uid!);
    } catch (_) {
      _unavailable = true;
    }
    notifyListeners();
  }

  Future<void> setNickname(String value) async {
    final uid = _uid;
    if (uid == null || _unavailable) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    try {
      await _service.setNickname(uid, trimmed);
      _nickname = trimmed;
      notifyListeners();
    } catch (_) {
      // Falhou silenciosamente — usuário pode tentar de novo pelo diálogo.
    }
  }

  Future<void> watchCompetition(String competitionId) async {
    if (_unavailable) return;
    _loadingRanking = true;
    notifyListeners();
    try {
      _topByCompetition[competitionId] =
          await _service.topEntries(competitionId);
    } catch (_) {
      // Mantém o que já tinha em cache, se houver.
    } finally {
      _loadingRanking = false;
      notifyListeners();
    }
  }

  /// Chamado a cada rebuild do Bolão com o total já calculado localmente —
  /// idempotente e barato de chamar sempre, igual `BolaoProvider.load()` já
  /// é hoje: só sincroniza de verdade quando o total mudou desde a última
  /// vez, e só depois que a pessoa escolheu um apelido.
  Future<void> syncIfChanged(
    String competitionId,
    String editionId,
    int points,
    int predictionsMade,
  ) async {
    if (_unavailable || !hasNickname) return;
    final uid = _uid;
    if (uid == null) return;
    final key = '$competitionId::$editionId';
    if (_lastSyncedPoints[key] == points) return;
    try {
      await _service.pushScore(
        competitionId: competitionId,
        uid: uid,
        nickname: _nickname!,
        points: points,
        predictionsMade: predictionsMade,
        editionId: editionId,
      );
      _lastSyncedPoints[key] = points;
      await watchCompetition(competitionId);
    } catch (_) {
      // Não marca como sincronizado — tenta de novo na próxima chamada.
    }
  }
}
