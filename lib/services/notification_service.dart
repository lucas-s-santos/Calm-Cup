import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/match.dart';
import '../utils/team_flags.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _enabledKey = 'notifications_enabled';
  static const _channelId = 'calmcup_matches';
  static const _channelName = 'Jogos da Copa';

  // IDs reservados por partida: base*10+0 (15min antes), +1 (início), +2 (fim), +3 (ao vivo)
  static const _liveIdOffset = 3;

  // Resultado do último `canScheduleExactNotifications()`. Consultado uma vez
  // por rodada de agendamento (e não por alarme) pra não pagar 300 chamadas
  // de canal; zerado no início de cada `scheduleMatchNotifications` porque a
  // pessoa pode ter concedido a permissão nas configurações do sistema entre
  // uma rodada e outra.
  bool? _exactAlarmsAllowed;

  Future<void> initialize() async {
    // flutter_local_notifications e Platform.isX (dart:io) não existem na
    // Web — o app roda sem notificações lá, sem quebrar o boot.
    if (kIsWeb) return;

    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Alertas de início e fim dos jogos da Copa do Mundo',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
    }
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await impl?.requestNotificationsPermission() ?? false;
      return granted;
    } else if (Platform.isIOS) {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await impl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  /// `true` quando o sistema permite alarmes exatos.
  ///
  /// A partir do Android 14 a permissão `SCHEDULE_EXACT_ALARM` deixou de ser
  /// concedida automaticamente na instalação: só apps de alarme/calendário
  /// qualificam pra `USE_EXACT_ALARM` (e a política do Play barra um app de
  /// futebol nessa categoria). Sem a permissão, `zonedSchedule` com
  /// `exactAllowWhileIdle` lança `exact_alarms_not_permitted` no lado nativo
  /// — por isso todo agendamento passa por aqui antes.
  ///
  /// iOS não tem esse conceito (as notificações locais são sempre exatas).
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Agenda as notificações das partidas e devolve quantas foram realmente
  /// agendadas — o chamador usa esse número pra não prometer à pessoa um
  /// alerta que o sistema recusou.
  ///
  /// Quando alarmes exatos não estão disponíveis, cai para
  /// `inexactAllowWhileIdle` em vez de falhar: para um aviso de "15 minutos
  /// antes" a folga que o Android se dá é irrelevante, e é infinitamente
  /// melhor que nenhuma notificação.
  Future<int> scheduleMatchNotifications(List<Match> matches) async {
    if (kIsWeb) return 0;
    await _plugin.cancelAll();
    _exactAlarmsAllowed = await canScheduleExactAlarms();
    final now = DateTime.now();
    var scheduled = 0;

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final kickoff = match.dateTime;

      // Fase mata-mata tem duração maior (tempo extra)
      final matchDuration =
          Duration(minutes: match.isKnockoutStage ? 120 : 105);

      // Ignora jogos já encerrados
      if (kickoff.add(matchDuration).isBefore(now)) continue;

      final flag1 = TeamFlags.get(match.team1);
      final flag2 = TeamFlags.get(match.team2);
      final teams = '$flag1 ${match.team1} x ${match.team2} $flag2';
      final phase = match.group != null ? 'Grupo ${match.group}' : match.round;

      // Se o jogo está acontecendo agora, dispara notificação imediata
      if (kickoff.isBefore(now) && kickoff.add(matchDuration).isAfter(now)) {
        final elapsed = now.difference(kickoff).inMinutes;
        await _show(
          id: i * 10 + _liveIdOffset,
          title: '🟢 Jogo ao vivo! $elapsedʼ',
          body: '$teams — $phase',
        );
      }

      if (await _schedule(
        id: i * 10,
        title: '⚽ Jogo em 15 minutos!',
        body: '$teams | $phase',
        when: kickoff.subtract(const Duration(minutes: 15)),
        now: now,
      )) {
        scheduled++;
      }

      if (await _schedule(
        id: i * 10 + 1,
        title: '🟢 Bola rolando!',
        body: '$teams — $phase',
        when: kickoff,
        now: now,
      )) {
        scheduled++;
      }

      if (await _schedule(
        id: i * 10 + 2,
        title: '🏁 Fim de jogo!',
        body: teams,
        when: kickoff.add(matchDuration),
        now: now,
      )) {
        scheduled++;
      }
    }

    return scheduled;
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(id, title, body, _detailsFor(body));
    } catch (_) {
      // Mesma regra do agendamento: uma notificação recusada não derruba o resto.
    }
  }

  /// Agenda um alarme e devolve se ele foi de fato aceito pelo sistema.
  ///
  /// Nunca lança: uma partida cujo alarme o Android recusar não pode
  /// interromper o agendamento das outras ~300 (era exatamente esse o efeito
  /// de deixar a exceção subir daqui).
  Future<bool> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required DateTime now,
  }) async {
    if (when.isBefore(now)) return false;

    final tzWhen = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      when.millisecondsSinceEpoch,
    );

    Future<void> send(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          tzWhen,
          _detailsFor(body),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

    final exact = _exactAlarmsAllowed ?? false;
    try {
      await send(exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
      return true;
    } on PlatformException catch (e) {
      // A permissão pode ter sido revogada entre a checagem e este alarme.
      // Marca pro resto da rodada e repete este mesmo alarme como inexato.
      if (e.code == 'exact_alarms_not_permitted' && exact) {
        _exactAlarmsAllowed = false;
        try {
          await send(AndroidScheduleMode.inexactAllowWhileIdle);
          return true;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Mesmo visual para notificação imediata e agendada.
  NotificationDetails _detailsFor(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF1E1E1E),
          autoCancel: true,
        ),
      );

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
