import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/match.dart';

class NotificationToggle extends StatefulWidget {
  final List<Match> matches;
  const NotificationToggle({super.key, required this.matches});

  @override
  State<NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<NotificationToggle> {
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await NotificationService.instance.isEnabled;
    if (mounted) setState(() { _enabled = enabled; _loading = false; });
  }

  Future<void> _toggle() async {
    final ns = NotificationService.instance;

    if (_enabled) {
      await ns.setEnabled(false);
      await ns.cancelAllNotifications();
      if (mounted) setState(() => _enabled = false);
      _showSnack('🔕 Notificações desativadas');
      return;
    }

    final granted = await ns.requestPermission();
    if (!granted) {
      _showSnack('Permissão de notificação negada nas configurações do sistema');
      return;
    }

    await ns.setEnabled(true);
    // Conta o que o sistema aceitou de verdade, não o que a gente pediu —
    // no Android 14+ sem permissão de alarme exato o agendamento cai pra
    // inexato, e se nem isso passar o número precisa refletir a realidade.
    final scheduled = await ns.scheduleMatchNotifications(widget.matches);
    if (mounted) setState(() => _enabled = true);

    if (scheduled == 0) {
      _showSnack('Nenhum jogo futuro para notificar');
      return;
    }

    final games = widget.matches
        .where((m) => m.dateTime.isAfter(DateTime.now()))
        .length;
    _showSnack('🔔 Notificações ativadas para $games jogos');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 48);
    return IconButton(
      tooltip: _enabled ? 'Desativar notificações' : 'Reativar notificações',
      icon: Icon(
        _enabled ? Icons.notifications_active : Icons.notifications_off,
        color: _enabled ? const Color(0xFFFFD700) : Colors.white38,
      ),
      onPressed: _toggle,
    );
  }
}
