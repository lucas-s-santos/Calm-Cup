import 'package:flutter_test/flutter_test.dart';
import 'package:calmcup/models/competition.dart';
import 'package:calmcup/services/openfootball_text_service.dart';

// Recortes reais (não inventados) de:
// - openfootball/south-america/brazil/2025_br1.txt (Brasileirão)
// - openfootball/south-america/copa-libertadores/2025_copal.txt (Libertadores)
// - openfootball/champions-league/2025-26/cl.txt (Champions League atual)
// - openfootball/copa-america/2024--usa/copa.txt (Copa América)

const _brasileirao = '''
= Brasileiro Série A 2025

# Date       Sat Mar 29 - Sun Dec 7 2025 (253d)
# Teams      20
# Matches    380

▪ Matchday 1
  Sat Mar 29 2025
    18:30  São Paulo FC            v SC Recife                0-0
           Cruzeiro EC             v Mirassol FC              2-1 (2-1)
    21:00  CR Flamengo             v SC Internacional         1-1 (0-1)
  Sun Mar 30
    16:00  SE Palmeiras            v Botafogo FR              0-0

▪ Matchday 2
  Sat Apr 5
    18:30  SC Corinthians Paulista v CR Vasco da Gama         3-0 (2-0)
''';

const _libertadores = '''
= Copa Libertadores 2025

# Date       Tue Feb 4 - Sat Nov 29 2025 (298d)
# Teams      47
# Matches    155

▪ Qualifying, Round 1
  Tue Feb 4 2025
    21:30  Monagas SC (VEN)        v Defensor SC (URU)        2-0 (0-0)
  Wed Feb 5
    21:30  Club Nacional (PAR)     v Club Alianza Lima (PER)  1-1 (1-0)
  Thu Feb 6
    21:30  CSCyD El Nacional (ECU) v CD Blooming (BOL)        4-3 pen. (2-1, 0-1)

▪ Group, Matchday 1
  Tue Mar 4
    21:30  CA Boca Juniors (ARG)   v Club Alianza Lima (PER)  2-0 (1-0)
''';

const _championsLeague = '''
= UEFA Champions League 2025/26

# Date       Tue Sep 16 2025 - Sat May 30 2026 (256d)

▪ League, Matchday 1
  Tue Sep 16 2025
    18:45  Athletic Club (ESP)     v Arsenal FC (ENG)         0-2 (0-0)
           PSV (NED)               v Royale Union Saint-Gilloise (BEL)  1-3 (0-2)
  Wed Sep 17
    18:45  PAE Olympiakos SFP (GRE) v Paphos FC (CYP)          0-0

▪ Playoffs, Matchday 1
  Tue Feb 17
    18:45  Galatasaray SK (TUR)    v Juventus FC (ITA)        5-2 (1-2)

▪ Finals, Final
  Sat May 30
    18:00  Paris Saint-Germain FC (FRA) v Arsenal FC (ENG)         4-3 pen. 1-1 a.e.t. (1-1, 0-1)
''';

const _copaAmerica = '''
= Copa América 2024      # in USA

Group A  |  Argentina       Peru       Chile      Canada

▪ Matchday 1  |  Thu Jun 20 - Mon Jun 24

▪ Group A

Thu Jun 20 20:00 UTC-4   Argentina      2-0   Canada  @ Mercedes-Benz Stadium, Atlanta, Georgia
                 (Álvarez 49' La. Martínez 88')
Fri Jun 21 19:00 UTC-5   Peru           0-0   Chile   @ AT&T Stadium, Arlington, Texas

▪ Quarter-finals

Thu Jul 4 20:00 UTC-5   Argentina  4-2 pen. (1-1) Ecuador   @ NRG Stadium, Houston, Texas    # Winner Group A - Runner-up Group B
                          (Li. Martínez 35'; Rodríguez 90+2')

▪ Final

Sat Jul 14 20:00 UTC-4   Argentina 1-0 a.e.t. (0-0) Colombia       @ Hard Rock Stadium, Miami Gardens, Florida    # Winner Match 29 - Winner Match 30
''';

void main() {
  final api = OpenFootballTextService();

  group('Dialeto A (bloco de data) — Brasileirão', () {
    late final matches = api.parseMatches(_brasileirao, TextDialect.dateBlock);

    test('parseia todas as partidas de ambas as rodadas', () {
      expect(matches, hasLength(5));
    });

    test('primeira partida: rodada, data, hora e placar corretos', () {
      final m = matches.first;
      expect(m.round, 'Matchday 1');
      expect(m.date, '2025-03-29');
      expect(m.time, '18:30');
      expect(m.team1, 'São Paulo FC');
      expect(m.team2, 'SC Recife');
      expect(m.score?.ft, [0, 0]);
      expect(m.score?.ht, isNull);
    });

    test('linha de continuação (sem horário) herda o horário anterior', () {
      final m = matches[1]; // Cruzeiro x Mirassol, mesma linha de 18:30
      expect(m.time, '18:30');
      expect(m.score?.ft, [2, 1]);
      expect(m.score?.ht, [2, 1]);
    });

    test('nova data sem ano herda o ano da última data explícita', () {
      final m = matches.firstWhere((m) => m.team1 == 'SE Palmeiras');
      expect(m.date, '2025-03-30');
    });

    test('segunda rodada é reconhecida como rodada própria', () {
      final m = matches.last;
      expect(m.round, 'Matchday 2');
      expect(m.date, '2025-04-05');
    });
  });

  group('Dialeto A — Libertadores (nomes com país + agregado com pênaltis)', () {
    late final matches = api.parseMatches(_libertadores, TextDialect.dateBlock);

    test('mantém o sufixo de país como parte do nome do time', () {
      final m = matches.first;
      expect(m.team1, 'Monagas SC (VEN)');
      expect(m.team2, 'Defensor SC (URU)');
    });

    test('agregado com pênaltis: mostra o placar principal sem lançar', () {
      final m = matches.firstWhere((m) => m.team1.contains('El Nacional'));
      expect(m.score?.ft, [4, 3]);
    });

    test('sem campo de grupo (fonte não informa) — Grupos fica vazio na tela', () {
      expect(matches.every((m) => m.group == null), isTrue);
    });

    test('rodada "Group, Matchday 1" preservada como está', () {
      final m = matches.last;
      expect(m.round, 'Group, Matchday 1');
    });
  });

  group('Dialeto A — Champions League (fase de liga x playoffs x final)', () {
    late final matches = api.parseMatches(_championsLeague, TextDialect.dateBlock);

    test('rodadas distintas preservadas literalmente', () {
      expect(matches.map((m) => m.round).toSet(), {
        'League, Matchday 1',
        'Playoffs, Matchday 1',
        'Finals, Final',
      });
    });

    test('placar sem 1º tempo (0-0) não lança', () {
      final m = matches.firstWhere((m) => m.team1.contains('Olympiakos'));
      expect(m.score?.ft, [0, 0]);
      expect(m.score?.ht, isNull);
    });

    test('linha com pen. + a.e.t. combinados: cai no placar principal', () {
      final m = matches.firstWhere((m) => m.round == 'Finals, Final');
      expect(m.score?.ft, [4, 3]);
    });
  });

  group('Dialeto B (linha única com local) — Copa América', () {
    late final matches =
        api.parseMatches(_copaAmerica, TextDialect.singleLineWithVenue);

    test('parseia jogos de grupo e de mata-mata', () {
      expect(matches, hasLength(4));
    });

    test('jogo de grupo: data (com ano do título), hora+fuso, grupo e local',
        () {
      final m = matches.first;
      expect(m.date, '2024-06-20');
      expect(m.time, '20:00 UTC-4');
      expect(m.team1, 'Argentina');
      expect(m.team2, 'Canada');
      expect(m.group, 'Group A');
      expect(m.round, 'Group A');
      expect(m.ground, 'Mercedes-Benz Stadium, Atlanta, Georgia');
      expect(m.score?.ft, [2, 0]);
    });

    test('ignora a linha de artilheiros abaixo do jogo', () {
      // Só 2 jogos no Group A do fixture — a linha "(Álvarez 49'...)" não
      // deve ter virado uma partida fantasma.
      final groupA = matches.where((m) => m.group == 'Group A');
      expect(groupA, hasLength(2));
    });

    test('mata-mata (Quarter-finals) não tem grupo', () {
      final m = matches.firstWhere((m) => m.round == 'Quarter-finals');
      expect(m.group, isNull);
      expect(m.team1, 'Argentina');
      expect(m.team2, 'Ecuador');
    });

    test('decidido nos pênaltis: ft = placar antes da disputa, p = pênaltis', () {
      final m = matches.firstWhere((m) => m.round == 'Quarter-finals');
      expect(m.score?.ft, [1, 1]);
      expect(m.score?.p, [4, 2]);
    });

    test('decidido na prorrogação: ft = placar nos 90min, et = após prorrogação',
        () {
      final m = matches.firstWhere((m) => m.round == 'Final');
      expect(m.score?.ft, [0, 0]);
      expect(m.score?.et, [1, 0]);
    });

    test('comentário "# Winner Group..." não vaza pro nome do local', () {
      final m = matches.firstWhere((m) => m.round == 'Quarter-finals');
      expect(m.ground, 'NRG Stadium, Houston, Texas');
    });
  });
}
