// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D5A27),
          background: const Color(0xFFF5F0E8),
        ),
        fontFamily: 'monospace',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/':         (ctx) => const HomeScreen(),
        '/history':  (ctx) => const HistoryScreen(),
        '/settings': (ctx) => const SettingsScreen(),
      },
    );
  }
}
