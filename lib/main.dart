import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/copa_2026_provider.dart';
import 'providers/history_provider.dart';
import 'providers/simulator_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await NotificationService.instance.initialize();
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
