/// Conversão tolerante de valores vindos de JSON externo.
///
/// As fontes (openfootball/rezarahiminia) misturam tipos no mesmo arquivo —
/// p.ex. o placar vem como número mas o minuto do gol vem como texto
/// (`"minute": "9"`). Um `as int` direto quebra o parsing inteiro e derruba
/// todas as telas com "Erro ao carregar dados". Estas funções aceitam `int`,
/// `num` ou `String` numérica e nunca lançam.
int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

int asIntOr(dynamic v, int fallback) => asIntOrNull(v) ?? fallback;
