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
  bool _enabled = false;
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

    // Pede permissão antes de ativar
    final granted = await ns.requestPermission();
    if (!granted) {
      _showSnack('Permissão de notificação negada');
      return;
    }

    await ns.setEnabled(true);
    await ns.scheduleMatchNotifications(widget.matches);
    if (mounted) setState(() => _enabled = true);

    final count = widget.matches
        .where((m) => m.dateTime.isAfter(DateTime.now()))
        .length;
    _showSnack('🔔 Notificações ativadas para $count jogos');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF1A472A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 48);
    return IconButton(
      tooltip: _enabled ? 'Desativar notificações' : 'Ativar notificações',
      icon: Icon(
        _enabled ? Icons.notifications_active : Icons.notifications_none,
        color: _enabled ? const Color(0xFFFFD700) : Colors.white54,
      ),
      onPressed: _toggle,
    );
  }
}
