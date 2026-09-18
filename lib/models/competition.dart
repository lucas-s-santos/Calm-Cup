/// Como a competição organiza suas partidas — decide se a tela mostra uma
/// tabela de classificação por grupo (`groupsAndKnockout`) ou uma única
/// tabela com todos os times (`league`, que também cobre a fase de liga da
/// Champions League: suas partidas de mata-mata não têm "Matchday" no nome
/// da rodada, então não entram na tabela — ver `CompetitionProvider`).
///
/// Competições sem grupo por partida na fonte de dados (ex.: Libertadores)
/// também usam `groupsAndKnockout` — a aba Grupos simplesmente fica vazia
/// (`CompetitionProvider.groupNames` retorna `[]`), sem precisar de um flag
/// à parte.
enum CompetitionFormat { groupsAndKnockout, league }

/// Formato da fonte de dados de uma [CompetitionEdition]. `json` é o schema
/// do openfootball já usado pela Copa do Mundo/Euro/ligas/parte da Champions
/// League; `text` é o formato legado de súmula em texto (duas variações —
/// ver [TextDialect]) usado por Brasileirão/Libertadores/Copa América/
/// Champions League em temporadas sem JSON.
enum DataSourceFormat { json, text }

/// As duas variações do formato de texto legado do openfootball,
/// confirmadas contra arquivos reais (não documentação):
/// - [dateBlock]: bloco `▪ Estágio, Rodada` → linha de data → uma-ou-mais
///   `HH:MM  Time1  v Time2  N-N (ht-ht)` por data. Usado por Brasileirão,
///   Libertadores e Champions League.
/// - [singleLineWithVenue]: bloco `Group X | Time1 Time2...` no topo,
///   depois `▪ Fase` → uma partida por linha com dia/hora/fuso, placar sem
///   1º tempo e local do jogo. Só a Copa América usa esse formato.
enum TextDialect { dateBlock, singleLineWithVenue }

/// Uma temporada/edição navegável de uma [Competition] (ex.: "2024",
/// "2024/25"). Cada edição tem sua própria URL de partidas — mesma ideia do
/// antigo `WorldCupApiService.historicalYears`, mas cabendo em qualquer
/// competição, não só Copa do Mundo. `sourceFormat`/`textDialect` são por
/// edição (não por competição) porque a MESMA competição pode ter temporadas
/// em formatos diferentes — a Champions League tem JSON só em 2019-20 e
/// 2024-25; todas as outras temporadas só existem em texto.
class CompetitionEdition {
  final String id;
  final String label;
  final String matchesUrl;
  final DataSourceFormat sourceFormat;
  final TextDialect? textDialect;

  const CompetitionEdition({
    required this.id,
    required this.label,
    required this.matchesUrl,
    this.sourceFormat = DataSourceFormat.json,
    this.textDialect,
  }) : assert(
          sourceFormat != DataSourceFormat.text || textDialect != null,
          'textDialect é obrigatório quando sourceFormat é text',
        );
}

/// Uma competição selecionável no app (Eurocopa, Champions League, uma liga
/// nacional...). Copa do Mundo 2026 fica de fora deste catálogo — continua
/// com sua própria aba fixa e `Copa2026Provider` dedicado.
class Competition {
  final String id;
  final String name;
  final String emoji;
  final CompetitionFormat format;
  final List<CompetitionEdition> editions;

  const Competition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.format,
    required this.editions,
  });
}
