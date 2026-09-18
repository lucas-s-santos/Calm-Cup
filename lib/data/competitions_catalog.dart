import '../models/competition.dart';

// Todas as URLs abaixo foram conferidas manualmente (HTTP 200) antes de
// entrarem aqui. As de JSON usam o mesmo schema da Copa do Mundo, sem parser
// novo (OpenFootballJsonService); as marcadas com `sourceFormat: .text` usam
// o formato de súmula legado, parseado por OpenFootballTextService.
const _footballJson =
    'https://raw.githubusercontent.com/openfootball/football.json/master';
const _euroJson = 'https://raw.githubusercontent.com/openfootball/euro.json/master';
const _southAmerica =
    'https://raw.githubusercontent.com/openfootball/south-america/master';
const _championsLeagueText =
    'https://raw.githubusercontent.com/openfootball/champions-league/master';
const _copaAmerica =
    'https://raw.githubusercontent.com/openfootball/copa-america/master';

/// Catálogo de competições além da Copa do Mundo 2026. Adicionar uma nova
/// competição com dados já em JSON (mesmo schema) é só adicionar uma entrada
/// aqui — sem código novo.
const List<Competition> competitionsCatalog = [
  Competition(
    id: 'euro',
    name: 'Eurocopa',
    emoji: '🇪🇺',
    format: CompetitionFormat.groupsAndKnockout,
    editions: [
      CompetitionEdition(
        id: '2024',
        label: '2024',
        matchesUrl: '$_euroJson/2024/euro.json',
      ),
      CompetitionEdition(
        id: '2020',
        label: '2020',
        matchesUrl: '$_euroJson/2020/euro.json',
      ),
    ],
  ),
  Competition(
    id: 'champions-league',
    name: 'Champions League',
    emoji: '⭐',
    format: CompetitionFormat.league,
    // A 2026/27 (temporada em andamento) ainda não existe nesta fonte —
    // conferido em 2026-09-18, o repositório não é atualizado desde
    // 2026-07-02, antes do início da temporada nova. 2025/26 continua sendo
    // a edição mais recente disponível (já encerrada); atualizar pra
    // 2026-27 assim que o repositório publicar (mesmo padrão das 6 ligas
    // europeias logo abaixo).
    editions: [
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_championsLeagueText/2025-26/cl.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.dateBlock,
      ),
      CompetitionEdition(
        id: '2024-25',
        label: '2024/25',
        matchesUrl: '$_footballJson/2024-25/uefa.cl.json',
      ),
      CompetitionEdition(
        id: '2019-20',
        label: '2019/20',
        matchesUrl: '$_footballJson/2019-20/uefa.cl.json',
      ),
    ],
  ),
  Competition(
    id: 'premier-league',
    name: 'Premier League',
    emoji: '🏴',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/en.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/en.1.json',
      ),
    ],
  ),
  Competition(
    id: 'la-liga',
    name: 'La Liga',
    emoji: '🇪🇸',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/es.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/es.1.json',
      ),
    ],
  ),
  Competition(
    id: 'serie-a',
    name: 'Serie A',
    emoji: '🇮🇹',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/it.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/it.1.json',
      ),
    ],
  ),
  Competition(
    id: 'bundesliga',
    name: 'Bundesliga',
    emoji: '🇩🇪',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/de.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/de.1.json',
      ),
    ],
  ),
  Competition(
    id: 'ligue-1',
    name: 'Ligue 1',
    emoji: '🇫🇷',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/fr.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/fr.1.json',
      ),
    ],
  ),
  Competition(
    id: 'primeira-liga',
    name: 'Primeira Liga',
    emoji: '🇵🇹',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026-27',
        label: '2026/27',
        matchesUrl: '$_footballJson/2026-27/pt.1.json',
      ),
      CompetitionEdition(
        id: '2025-26',
        label: '2025/26',
        matchesUrl: '$_footballJson/2025-26/pt.1.json',
      ),
    ],
  ),
  Competition(
    id: 'brasileirao',
    name: 'Brasileirão Série A',
    emoji: '🇧🇷',
    format: CompetitionFormat.league,
    editions: [
      CompetitionEdition(
        id: '2026',
        label: '2026',
        matchesUrl: '$_southAmerica/brazil/2026_br1.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.dateBlock,
      ),
      CompetitionEdition(
        id: '2025',
        label: '2025',
        matchesUrl: '$_southAmerica/brazil/2025_br1.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.dateBlock,
      ),
    ],
  ),
  Competition(
    id: 'libertadores',
    name: 'Copa Libertadores',
    emoji: '🏆',
    // A fonte não informa o grupo de cada partida (só o estágio "Group,
    // Matchday N") — a aba Grupos fica vazia automaticamente, mostrando só
    // a lista de jogos por rodada (decisão já tomada, ver plano da Fase 1).
    format: CompetitionFormat.groupsAndKnockout,
    editions: [
      CompetitionEdition(
        id: '2026',
        label: '2026',
        matchesUrl: '$_southAmerica/copa-libertadores/2026_copal.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.dateBlock,
      ),
      CompetitionEdition(
        id: '2025',
        label: '2025',
        matchesUrl: '$_southAmerica/copa-libertadores/2025_copal.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.dateBlock,
      ),
    ],
  ),
  Competition(
    id: 'copa-america',
    name: 'Copa América',
    emoji: '🌎',
    format: CompetitionFormat.groupsAndKnockout,
    editions: [
      CompetitionEdition(
        id: '2024',
        label: '2024',
        matchesUrl: '$_copaAmerica/2024--usa/copa.txt',
        sourceFormat: DataSourceFormat.text,
        textDialect: TextDialect.singleLineWithVenue,
      ),
    ],
  ),
];
