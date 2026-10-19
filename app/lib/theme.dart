import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/common.dart';

/// Light and dark looks, and the user's choice between them (saved on the phone).
class AppTheme {
  /// system follows the phone's own dark mode setting.
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode.value = switch (p.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', m.name);
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// The home screen's quick switch: flips whatever is showing now.
  static Future<void> toggle(BuildContext context) =>
      set(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // In dark mode the seed's own light green is the accent, so outlined buttons,
    // borders and icons stay readable on the dark background.
    final scheme = dark
        ? ColorScheme.fromSeed(seedColor: kGreen, brightness: Brightness.dark)
        : ColorScheme.fromSeed(
            seedColor: kGreen,
            primary: kGreen,
            brightness: Brightness.light,
          );
    final surface = dark ? const Color(0xFF1E2725) : Colors.white;
    final text = dark ? Colors.white : Colors.black;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF121816)
          : const Color(0xFFFFF8EE),
    );
    return base.copyWith(
      // ThemeData's own textTheme has no font sizes yet (they're added per locale
      // later), so scale the "tall" geometry meant for scripts like Devanagari.
      textTheme: Typography.tall2021
          .merge(
            dark ? Typography.whiteMountainView : Typography.blackMountainView,
          )
          .apply(fontSizeFactor: 1.25, bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        toolbarHeight: 64,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(fontSize: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(color: surface, elevation: 2),
    );
  }
}
