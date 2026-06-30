import 'package:flutter/material.dart';

/// Paleta central do app. Centraliza as cores que antes estavam espalhadas
/// como literais (`0xFFFFD700`, `0xFF0D1A0D`, …) em dezenas de arquivos.
class AppColors {
  AppColors._();

  /// Dourado de destaque (acento principal).
  static const gold = Color(0xFFFFD700);

  /// Fundo padrão das telas.
  static const bg = Color(0xFF0D1A0D);

  /// Fundo mais escuro (barra de navegação inferior).
  static const bgDarker = Color(0xFF0A150A);

  /// Verde "gramado" — app bar, headers, acentos secundários.
  static const green = Color(0xFF1A472A);

  /// Verde claro de header de seção (Seleções/Estádios).
  static const greenHeader = Color(0xFF1A3A1A);

  /// Cartão padrão de partida.
  static const card = Color(0xFF1A2A1A);

  /// Cartão alternativo (grupos, estádios, listas).
  static const cardAlt = Color(0xFF131F13);

  /// Borda neutra de cartões sem resultado.
  static const cardBorder = Color(0xFF243024);

  /// Vermelho de "AO VIVO".
  static const live = Color(0xFFE53935);
}
