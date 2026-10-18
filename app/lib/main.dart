import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'strings.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.load();
  runApp(const RepairwalaApp());
}

class RepairwalaApp extends StatelessWidget {
  const RepairwalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kGreen,
      primary: kGreen,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFFF8EE),
    );
    return MaterialApp(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        // ThemeData's own textTheme has no font sizes yet (they're added per locale
        // later), so scale the "tall" geometry meant for scripts like Devanagari.
        textTheme: Typography.tall2021.merge(Typography.blackMountainView).apply(
          fontSizeFactor: 1.25,
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          toolbarHeight: 64,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 2),
      ),
      home: api.configured ? const HomeScreen() : const SettingsScreen(first: true),
    );
  }
}
