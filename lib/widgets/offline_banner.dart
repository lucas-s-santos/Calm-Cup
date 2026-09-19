import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Faixa discreta avisando que o que está na tela veio do cache offline.
///
/// Diferente do cartão de erro: aqui os dados *existem* e são utilizáveis —
/// só podem estar desatualizados porque a atualização falhou. Por isso é uma
/// faixa fina em tom de aviso, e não uma tela inteira em vermelho.
class OfflineBanner extends StatelessWidget {
  /// Texto curto explicando o que exatamente está desatualizado.
  final String message;

  const OfflineBanner({
    super.key,
    this.message = 'Sem conexão — mostrando os últimos dados salvos.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.gold.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
