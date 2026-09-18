/// Resolve a URL do escudo real de um clube a partir de repositórios
/// públicos gratuitos no GitHub (mesmo espírito de fonte livre já usado pro
/// resto dos dados do app — nunca um serviço pago/com chave):
/// - `luukhopman/football-logos`: as 6 ligas europeias do catálogo.
/// - `Lobobinho/Escudos-dos-Clubes-do-Brasileirao-2026`: os 20 clubes da
///   Série A 2026 — também cobre a parcela brasileira da Libertadores.
///
/// Nenhuma das duas cobre Copa América (são seleções nacionais — já caem na
/// bandeira via `TeamFlags`, não precisam de escudo de clube) nem os clubes
/// não-brasileiros da Libertadores (Argentina, Uruguai, Chile, Colômbia...)
/// — esses usam o badge de iniciais (`TeamBadge` cai nesse fallback sozinho
/// quando `urlsFor` não acha nenhuma fonte pro time).
///
/// Os nomes de time do openfootball raramente batem com o nome do arquivo
/// da fonte de escudo — cada exceção abaixo foi conferida de verdade
/// comparando as duas fontes lado a lado pra temporada 2025/26 (ligas
/// europeias) ou 2026 (Brasileirão), não adivinhada.
class ClubCrests {
  ClubCrests._();

  static const _euroBase =
      'https://raw.githubusercontent.com/luukhopman/football-logos/master/history/2025-26';
  static const _brBase =
      'https://raw.githubusercontent.com/Lobobinho/Escudos-dos-Clubes-do-Brasileirao-2026/master';

  static const Map<String, String> _leagueFolder = {
    'premier-league': 'England - Premier League',
    'la-liga': 'Spain - LaLiga',
    'serie-a': 'Italy - Serie A',
    'bundesliga': 'Germany - Bundesliga',
    'ligue-1': 'France - Ligue 1',
    'primeira-liga': 'Portugal - Liga Portugal',
  };

  static const Map<String, Map<String, String>> _leagueNameOverrides = {
    'la-liga': {
      'Athletic Club': 'Athletic Bilbao',
      'Club Atlético de Madrid': 'Atlético de Madrid',
      'RC Celta de Vigo': 'Celta de Vigo',
      'RCD Espanyol de Barcelona': 'RCD Espanyol Barcelona',
      'Rayo Vallecano de Madrid': 'Rayo Vallecano',
      'Real Madrid CF': 'Real Madrid',
      'Real Sociedad de Fútbol': 'Real Sociedad',
    },
    'serie-a': {
      'AC Pisa 1909': 'Pisa Sporting Club',
      'FC Internazionale Milano': 'Inter Milan',
      'Hellas Verona FC': 'Hellas Verona',
      'US Sassuolo Calcio': 'US Sassuolo',
    },
    'bundesliga': {
      '1. FC Heidenheim 1846': '1.FC Heidenheim 1846',
      '1. FC Köln': '1.FC Köln',
      '1. FC Union Berlin': '1.FC Union Berlin',
      '1. FSV Mainz 05': '1.FSV Mainz 05',
      'FC Bayern München': 'Bayern Munich',
      'FC St. Pauli 1910': 'FC St. Pauli',
    },
    'ligue-1': {
      'AS Monaco FC': 'AS Monaco',
      'Lille OSC': 'LOSC Lille',
      'Olympique Lyonnais': 'Olympique Lyon',
      'Olympique de Marseille': 'Olympique Marseille',
      'Paris Saint-Germain FC': 'Paris Saint-Germain',
      'Racing Club de Lens': 'RC Lens',
      'Stade Rennais FC 1901': 'Stade Rennais FC',
      'Toulouse FC': 'FC Toulouse',
    },
    'primeira-liga': {
      'AVS': 'Avs Futebol',
      'CF Estrela da Amadora': 'CF Estrela Amadora',
      'Sport Lisboa e Benfica': 'SL Benfica',
      'Sporting Clube de Braga': 'SC Braga',
      'Sporting Clube de Portugal': 'Sporting CP',
      'Vitória Guimarães': 'Vitória Guimarães SC',
    },
  };

  static const Map<String, String> _brasileiraoNameOverrides = {
    'Botafogo FR': 'Botafogo',
    'CA Mineiro': 'Atlético Mineiro',
    'CA Paranaense': 'Athletico Paranaense',
    'CR Flamengo': 'Flamengo',
    'CR Vasco da Gama': 'Vasco da Gama',
    'Chapecoense AF': 'Chapecoense',
    'Clube do Remo': 'Remo',
    'Coritiba FBC': 'Coritiba',
    'Cruzeiro EC': 'Cruzeiro',
    'EC Bahia': 'Bahia',
    'EC Vitória': 'Vitória',
    'Fluminense FC': 'Fluminense',
    'Grêmio FBPA': 'Grêmio',
    'Mirassol FC': 'Mirassol',
    'RB Bragantino': 'Red Bull Bragantino',
    'SC Corinthians Paulista': 'Corinthians',
    'SC Internacional': 'Internacional',
    'SE Palmeiras': 'Palmeiras',
    'Santos FC': 'Santos',
    'São Paulo FC': 'São Paulo',
  };

  /// A maioria dos times das ligas europeias bate com o próprio nome; o
  /// único padrão genérico que vale a pena tentar (em vez de virar mais uma
  /// exceção manual) é remover o "FC" que o openfootball agrega no fim do
  /// nome de metade dos times da Premier League — mas só como 2ª tentativa:
  /// pra alguns times (Arsenal FC, Chelsea FC, Liverpool FC...) o "FC" É
  /// parte do nome real e a fonte de escudos mantém.
  static String _stripTrailingFc(String name) =>
      name.endsWith(' FC') ? name.substring(0, name.length - 3) : name;

  /// Champions League e Libertadores anotam o país/confederação do time
  /// entre parênteses no fim do nome (ex.: "Arsenal FC (ENG)", "Club The
  /// Strongest (BOL)") — não existe na fonte de escudo nenhuma, precisa
  /// tirar antes de comparar.
  static final _countrySuffixRe = RegExp(r'^(.*\S)\s*\([A-Z]{2,3}\)$');
  static String _stripCountrySuffix(String name) {
    final m = _countrySuffixRe.firstMatch(name);
    return m != null ? m.group(1)! : name;
  }

  static List<String> _leagueUrls(String leagueId, String teamName) {
    final folder = _leagueFolder[leagueId];
    if (folder == null) return const [];
    final override = _leagueNameOverrides[leagueId]?[teamName];
    final stripped = _stripTrailingFc(teamName);
    final candidates = override != null
        ? [override]
        : stripped == teamName
            ? [teamName]
            : [teamName, stripped];
    return candidates
        .map((f) =>
            '$_euroBase/${Uri.encodeComponent(folder)}/${Uri.encodeComponent('$f.png')}')
        .toList();
  }

  static List<String> _brasileiraoUrls(String teamName) {
    final fileName = _brasileiraoNameOverrides[teamName] ?? teamName;
    return ['$_brBase/${Uri.encodeComponent('$fileName.png')}'];
  }

  /// URLs candidatas pro escudo, em ordem de preferência. `TeamBadge` tenta
  /// cada uma até uma carregar, e cai pro badge de iniciais se nenhuma
  /// existir — lista vazia quando a competição não tem fonte conhecida.
  static List<String> urlsFor(String competitionId, String teamName) {
    switch (competitionId) {
      case 'brasileirao':
        return _brasileiraoUrls(teamName);

      case 'libertadores':
        // Só a parcela brasileira tem escudo real disponível; o resto (Arg,
        // Uru, Chi, Col, Par, Equ, Ven, Bol...) não tem fonte gratuita
        // encontrada — cai em iniciais.
        if (teamName.endsWith('(BRA)')) {
          return _brasileiraoUrls(_stripCountrySuffix(teamName));
        }
        return const [];

      case 'champions-league':
        // Não dá pra saber de qual das 6 ligas um time da Champions é só
        // pelo id da competição — tenta as 6 em ordem; times de fora delas
        // (ligas belga, escocesa, turca, etc.) caem em iniciais.
        final base = _stripCountrySuffix(teamName);
        return _leagueFolder.keys.expand((l) => _leagueUrls(l, base)).toList();

      default:
        return _leagueUrls(competitionId, teamName);
    }
  }
}
