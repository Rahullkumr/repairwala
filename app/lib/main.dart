import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'strings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.load();
  await S.loadLang();
  await AppTheme.load();
  runApp(const RepairwalaApp());
}

class RepairwalaApp extends StatelessWidget {
  const RepairwalaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([S.lang, AppTheme.mode]),
      // The key restarts the app on its first screen when the language changes, so no
      // screen is left showing the old language. A theme change just repaints.
      builder: (context, _) => MaterialApp(
        key: ValueKey(S.lang.value),
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: AppTheme.mode.value,
        home: api.configured
            ? const HomeScreen()
            : const SettingsScreen(first: true),
      ),
    );
  }
}
