import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/match.dart';

Match _match({String? group, bool? isKnockoutStageOverride}) {
  return Match(
    round: group != null ? 'Group Stage' : 'Round of 16',
    date: '2026-06-20',
    time: '16:00',
    team1: 'A',
    team2: 'B',
    group: group,
    ground: 'Estádio',
    isKnockoutStageOverride: isKnockoutStageOverride,
  );
}

void main() {
  group('Match.isKnockoutStage', () {
    test('sem override, cai no heurístico antigo (group == null)', () {
      expect(_match(group: null).isKnockoutStage, isTrue);
      expect(_match(group: 'Group A').isKnockoutStage, isFalse);
    });

    test('override explícito tem precedência sobre o heurístico', () {
      // Jogo de liga: sem grupo (group == null) mas nunca tem prorrogação.
      expect(
        _match(group: null, isKnockoutStageOverride: false).isKnockoutStage,
        isFalse,
      );
    });

    test('copyWith preserva o override de isKnockoutStage', () {
      final original = _match(group: null, isKnockoutStageOverride: false);
      final copy = original.copyWith();
      expect(copy.isKnockoutStage, isFalse);
    });
  });
}
