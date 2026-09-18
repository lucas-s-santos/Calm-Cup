import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/providers/competition_provider.dart';

// Regressão: a fase de liga da Champions League 2024/25 é "League, Matchday
// N" (deve contar na tabela), mas os playoffs de acesso ao mata-mata
// (times 9º-24º) também se chamam "Playoffs, Matchday N" — descoberto só ao
// rodar o app de verdade contra dados reais, onde os times apareciam com
// PJ=10 em vez de 8 porque um filtro ingênuo (`round.contains('Matchday')`)
// incluía os playoffs por engano.
void main() {
  group('CompetitionProvider.countsTowardLeagueTable', () {
    test('conta rodadas de liga doméstica ("Matchday N")', () {
      expect(CompetitionProvider.countsTowardLeagueTable('Matchday 1'), isTrue);
      expect(CompetitionProvider.countsTowardLeagueTable('Matchday 38'), isTrue);
    });

    test('conta a fase de liga da Champions League ("League, Matchday N")', () {
      expect(
        CompetitionProvider.countsTowardLeagueTable('League, Matchday 8'),
        isTrue,
      );
    });

    test(
        'NÃO conta os playoffs de acesso ao mata-mata, mesmo tendo '
        '"Matchday" no nome', () {
      expect(
        CompetitionProvider.countsTowardLeagueTable('Playoffs, Matchday 1'),
        isFalse,
      );
    });

    test('NÃO conta as fases finais (oitavas em diante)', () {
      expect(CompetitionProvider.countsTowardLeagueTable('Finals, Round of 16'), isFalse);
      expect(CompetitionProvider.countsTowardLeagueTable('Finals, Final'), isFalse);
    });
  });
}
