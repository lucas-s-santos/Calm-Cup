import 'dart:io';
import 'package:flutter/material.dart' show Color;
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

  Future<void> initialize() async {
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
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<bool> requestPermission() async {
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

  Future<void> scheduleMatchNotifications(List<Match> matches) async {
    await _plugin.cancelAll();
    final now = DateTime.now();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final kickoff = match.dateTime;

      // Ignora jogos que já encerraram (mais de 105 min atrás)
      if (kickoff.add(const Duration(minutes: 105)).isBefore(now)) continue;

      final flag1 = TeamFlags.get(match.team1);
      final flag2 = TeamFlags.get(match.team2);
      final teams = '$flag1 ${match.team1} x ${match.team2} $flag2';
      final phase =
          match.group != null ? 'Grupo ${match.group}' : match.round;

      await _schedule(
        id: i * 10,
        title: '⚽ Jogo em 15 minutos!',
        body: teams,
        when: kickoff.subtract(const Duration(minutes: 15)),
        now: now,
      );

      await _schedule(
        id: i * 10 + 1,
        title: '🟢 Bola rolando!',
        body: '$teams — $phase',
        when: kickoff,
        now: now,
      );

      await _schedule(
        id: i * 10 + 2,
        title: '🏁 Fim de jogo!',
        body: teams,
        when: kickoff.add(const Duration(minutes: 105)),
        now: now,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required DateTime now,
  }) async {
    if (when.isBefore(now)) return;

    // Usa millisecondsSinceEpoch para preservar o horário absoluto correto
    final tzWhen = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.UTC,
      when.millisecondsSinceEpoch,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon:
              const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF1A472A),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
