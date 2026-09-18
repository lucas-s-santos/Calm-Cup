import 'package:flutter/material.dart';

/// Paleta central do app. Centraliza as cores que antes estavam espalhadas
/// como literais (`0xFFFFD700`, `0xFF121212`, …) em dezenas de arquivos.
///
/// Estilo "transmissão noturna": fundo grafite/azul-marinho quase preto (em
/// vez do verde-gramado original), dourado como acento principal — ligado
/// ao troféu da logo — e cores semânticas fixas pra resultado (vitória/
/// empate/derrota), independentes do tema.
class AppColors {
  AppColors._();

  /// Dourado de destaque (acento principal, ligado ao troféu da logo).
  static const gold = Color(0xFFFFD700);

  /// Fundo padrão das telas.
  static const bg = Color(0xFF121212);

  /// Fundo mais escuro (barra de navegação inferior).
  static const bgDarker = Color(0xFF0A0A0A);

  /// Superfície de destaque — app bar, headers. Antes era o verde-gramado;
  /// mantém o nome por compatibilidade com o restante do código.
  static const green = Color(0xFF1E1E1E);

  /// Superfície de header de seção (Seleções/Estádios).
  static const greenHeader = Color(0xFF262626);

  /// Cartão padrão de partida.
  static const card = Color(0xFF1A1A1A);

  /// Cartão alternativo (grupos, estádios, listas).
  static const cardAlt = Color(0xFF181818);

  /// Borda neutra de cartões sem resultado / linhas de conector do bracket.
  static const cardBorder = Color(0xFF2E2E2E);

  /// Vermelho de alerta — "AO VIVO", derrota.
  static const live = Color(0xFFEF4444);

  // ── Cores semânticas de resultado (fixas, não mudam com o tema) ─────────

  /// Vitória / positivo.
  static const win = Color(0xFF22C55E);

  /// Empate / neutro.
  static const draw = Color(0xFF94A3B8);

  /// Derrota / negativo — mesmo tom de [live] (ambos "vermelho de alerta").
  static const loss = Color(0xFFEF4444);
}
