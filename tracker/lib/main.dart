// lib/main.dart

import 'package:flutter/material.dart';
import 'services/config_service.dart';
import 'services/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = ConfigService();
  await config.initTranslations();
  final size     = await config.getSize();
  final contrast = await config.getContrast();
  AppTheme().init(size, contrast);
  runApp(const TrackerApp());
}

class TrackerApp extends StatelessWidget {
  const TrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2D5A27)),
        fontFamily: 'monospace',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/':          (ctx) => const HomeScreen(),
        '/history':   (ctx) => const HistoryScreen(),
        '/settings':  (ctx) => const SettingsScreen(),
        '/report':    (ctx) => const ReportScreen(),
      },
    );
  }
}
