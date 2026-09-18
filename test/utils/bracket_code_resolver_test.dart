import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/match.dart';
import 'package:calmcup/utils/bracket_code_resolver.dart';

Match _match({
  required String team1,
  required String team2,
  int? matchNum,
}) {
  return Match(
    round: 'Round of 16',
    date: '2026-06-20',
    time: '16:00',
    team1: team1,
    team2: team2,
    ground: 'Estádio',
    num: matchNum,
  );
}

void main() {
  group('BracketCodeResolver.isCode', () {
    test('reconhece códigos de posição, vencedor/perdedor e melhor 3º', () {
      expect(BracketCodeResolver.isCode('1A'), isTrue);
      expect(BracketCodeResolver.isCode('2L'), isTrue);
      expect(BracketCodeResolver.isCode('W73'), isTrue);
      expect(BracketCodeResolver.isCode('L101'), isTrue);
      expect(BracketCodeResolver.isCode('3A/B/C/D'), isTrue);
    });

    test('não reconhece nomes reais de seleção como código', () {
      expect(BracketCodeResolver.isCode('Brazil'), isFalse);
      expect(BracketCodeResolver.isCode('A definir'), isFalse);
    });
  });

  group('BracketCodeResolver.resolve', () {
    late Map<String, List<Map<String, dynamic>>> standings;

    setUp(() {
      standings = {
        'Group A': [
          {'team': 'Brazil', 'pts': 9, 'sg': 5, 'gp': 6},
          {'team': 'Serbia', 'pts': 6, 'sg': 1, 'gp': 3},
          {'team': 'Switzerland', 'pts': 3, 'sg': -2, 'gp': 2},
        ],
        'Group B': [
          {'team': 'Argentina', 'pts': 7, 'sg': 4, 'gp': 5},
          {'team': 'Poland', 'pts': 4, 'sg': 0, 'gp': 2},
          {'team': 'Mexico', 'pts': 4, 'sg': -1, 'gp': 1},
        ],
      };
    });

    test('resolve código de posição "1A"/"2B" via classificação', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('1A'), 'Brazil');
      expect(resolver.resolve('2B'), 'Poland');
    });

    test('código de posição sem classificação suficiente retorna o próprio código', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => {},
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('1A'), '1A');
    });

    test('resolve "W<num>"/"L<num>" recursivamente contra os times do jogo', () {
      final r16Match = _match(team1: '1A', team2: '2B', matchNum: 73);

      final resolver = BracketCodeResolver(
        matchByNum: (n) => n == 73 ? r16Match : null,
        resultOf: (m) => m == r16Match ? [2, 1] : null,
        standingsByGroup: () => standings,
        winnerIndex: (m, r) => r[0] > r[1] ? 0 : 1,
      );

      // team1 ("1A" -> Brazil) venceu por 2x1.
      expect(resolver.resolve('W73'), 'Brazil');
      expect(resolver.resolve('L73'), 'Poland');
    });

    test('sem resultado ainda, "W<num>" permanece como código', () {
      final match = _match(team1: 'Brazil', team2: 'Argentina', matchNum: 5);
      final resolver = BracketCodeResolver(
        matchByNum: (n) => n == 5 ? match : null,
        resultOf: (_) => null,
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('W5'), 'W5');
    });

    test('empate sem critério de desempate retorna o código (winnerIndex null)', () {
      final match = _match(team1: 'Brazil', team2: 'Argentina', matchNum: 5);
      final resolver = BracketCodeResolver(
        matchByNum: (n) => n == 5 ? match : null,
        resultOf: (_) => [1, 1],
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null, // ex.: empate sem pênaltis registrados
      );

      expect(resolver.resolve('W5'), 'W5');
    });

    test('melhor 3º ("3A/B") não repete time já atribuído a outra vaga', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null,
      );

      // Ambos os grupos têm exatamente um 3º colocado cada: Switzerland (A,
      // 3 pts) e Mexico (B, 4 pts). Mexico tem mais pontos -> sai primeiro.
      expect(resolver.resolve('3A/B'), 'Mexico');
      expect(resolver.resolve('3A/B'), 'Switzerland');
    });

    test(
        'fallbackToTopWhenExhausted=false (chaveamento real) deixa "A definir" '
        'quando os candidatos de melhor 3º já foram todos usados', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => {
          'Group A': [standings['Group A']![0], standings['Group A']![1], standings['Group A']![2]],
        },
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('3A'), 'Switzerland');
      expect(resolver.resolve('3A'), '3A'); // já atribuído, sem outro candidato
    });

    test(
        'fallbackToTopWhenExhausted=true (simulador) repete o melhor candidato '
        'em vez de deixar a vaga em aberto', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => {
          'Group A': [standings['Group A']![0], standings['Group A']![1], standings['Group A']![2]],
        },
        winnerIndex: (_, _) => null,
        fallbackToTopWhenExhausted: true,
      );

      expect(resolver.resolve('3A'), 'Switzerland');
      expect(resolver.resolve('3A'), 'Switzerland');
    });

    test('resetThirdPlaceAssignment libera os candidatos novamente', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('3A/B'), 'Mexico');
      resolver.resetThirdPlaceAssignment();
      expect(resolver.resolve('3A/B'), 'Mexico');
    });

    test('nome real de seleção (sem match de código) volta inalterado', () {
      final resolver = BracketCodeResolver(
        matchByNum: (_) => null,
        resultOf: (_) => null,
        standingsByGroup: () => standings,
        winnerIndex: (_, _) => null,
      );

      expect(resolver.resolve('Brazil'), 'Brazil');
    });
  });
}
