import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/copa_2026_provider.dart';
import 'providers/history_provider.dart';
import 'providers/simulator_provider.dart';
import 'providers/bolao_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';
import 'services/world_cup_api_service.dart';

const _bgTaskId = 'calmcup_reschedule';

// Roda em isolate separado pelo WorkManager — sem acesso ao estado da UI
@pragma('vm:entry-point')
void _bgCallback() {
  Workmanager().executeTask((_, _) async {
    try {
      await NotificationService.instance.initialize();

      if (!await NotificationService.instance.isEnabled) return true;

      final local = LocalStorageService();
      final api = WorldCupApiService();

      String? rawJson;
      try {
        rawJson = await api.fetchMatchesRaw(2026);
        await local.saveMatchesCache(rawJson);
      } catch (_) {
        rawJson = await local.loadMatchesCache();
      }

      if (rawJson != null) {
        final matches = api.parseMatchesFromRaw(rawJson);
        await NotificationService.instance.scheduleMatchNotifications(matches);
      }
    } catch (_) {}

    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await NotificationService.instance.initialize();

  // Pede permissão automaticamente — só mostra diálogo na primeira vez.
  // Em lançamentos subsequentes retorna imediatamente se já concedida.
  await NotificationService.instance.requestPermission();

  await Workmanager().initialize(_bgCallback, isInDebugMode: false);

  // Tarefa periódica a cada 12h: mantém notificações agendadas mesmo
  // com o app fechado, reinicializado ou com alarmes limpos pelo sistema.
  await Workmanager().registerPeriodicTask(
    _bgTaskId,
    _bgTaskId,
    frequency: const Duration(hours: 12),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(
      networkType: NetworkType.notRequired,
    ),
  );

  runApp(const CopaDoMundoApp());
}

class CopaDoMundoApp extends StatelessWidget {
  const CopaDoMundoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Copa2026Provider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SimulatorProvider()),
        ChangeNotifierProvider(create: (_) => BolaoProvider()),
      ],
      child: MaterialApp(
        title: 'Copa do Mundo',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A472A),
        brightness: Brightness.dark,
        primary: const Color(0xFFFFD700),
        secondary: const Color(0xFF1A472A),
        surface: const Color(0xFF0D1A0D),
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1A0D),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A472A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D1A0D),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: Color(0xFFFFD700), fontSize: 12);
          }
          return const TextStyle(color: Colors.white54, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFFD700));
          }
          return const IconThemeData(color: Colors.white54);
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFFFFD700),
        unselectedLabelColor: Colors.white54,
        indicatorColor: Color(0xFFFFD700),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white70),
      ),
    );
  }
}
