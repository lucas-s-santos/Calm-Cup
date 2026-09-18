// `continent`/`fifaCode`/`group`/`confed` só existem em fontes de seleções
// nacionais (worldcup.json/euro.json) — times de clube (ligas, Champions,
// Libertadores) não têm confederação FIFA nem grupo por seleção, por isso
// esses campos têm default vazio em vez de obrigatórios.
class Team {
  final String name;
  final String? nameNormalised;
  final String continent;
  final String flagIcon;
  final String fifaCode;
  final String group;
  final String confed;

  const Team({
    required this.name,
    this.nameNormalised,
    this.continent = '',
    required this.flagIcon,
    this.fifaCode = '',
    this.group = '',
    this.confed = '',
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      name: json['name'] as String,
      nameNormalised: json['name_normalised'] as String?,
      continent: json['continent'] as String? ?? '',
      flagIcon: json['flag_icon'] as String? ?? '🏳️',
      fifaCode: json['fifa_code'] as String? ?? '',
      group: json['group'] as String? ?? '',
      confed: json['confed'] as String? ?? '',
    );
  }

  String get displayName => nameNormalised ?? name;
}
