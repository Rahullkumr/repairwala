import 'package:flutter/material.dart';

import '../api.dart';
import '../strings.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  /// True on first launch: after saving we replace this screen with Home.
  final bool first;
  const SettingsScreen({super.key, this.first = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url = TextEditingController(
    text: api.baseUrl,
  );
  late final TextEditingController _token = TextEditingController(
    text: api.token,
  );
  Health? _health;
  bool _checking = false;
  bool _failed = false;

  Future<void> _save() async {
    await api.saveSettings(_url.text, _token.text);
    if (!mounted) return;
    showMsg(context, S.saved);
    if (widget.first && api.configured) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _check() async {
    await api.saveSettings(_url.text, _token.text);
    setState(() {
      _checking = true;
      _failed = false;
      _health = null;
    });
    try {
      final h = await api.health();
      if (mounted) setState(() => _health = h);
    } catch (e) {
      if (mounted) {
        setState(() => _failed = true);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _row(String label, IconData icon, bool? ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 22))),
        Text(
          ok == null ? '' : (ok ? '✅' : '❌'),
          style: const TextStyle(fontSize: 28),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final h = _health;
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language first, so a new user can pick it before reading anything else.
          Text(S.language, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'hi',
                label: Text('हिन्दी', style: TextStyle(fontSize: 20)),
              ),
              ButtonSegment(
                value: 'en',
                label: Text('English', style: TextStyle(fontSize: 20)),
              ),
            ],
            selected: {S.lang.value},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onSelectionChanged: (s) => S.setLang(s.first),
          ),
          const SizedBox(height: 20),
          Text(S.theme, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(
                  S.themeSystem,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(S.themeLight, style: const TextStyle(fontSize: 18)),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(S.themeDark, style: const TextStyle(fontSize: 18)),
              ),
            ],
            selected: {AppTheme.mode.value},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onSelectionChanged: (s) => AppTheme.set(s.first),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: S.serverAddress,
              prefixIcon: Icon(Icons.wifi),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _token,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              labelText: S.shopToken,
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(height: 20),
          BigButton(icon: Icons.save, label: S.save, onPressed: _save),
          const SizedBox(height: 12),
          BigButton(
            icon: Icons.network_check,
            label: _checking ? S.loading : S.check,
            outlined: true,
            onPressed: _checking ? null : _check,
          ),
          const SizedBox(height: 20),
          if (_checking) const Center(child: CircularProgressIndicator()),
          if (h != null || _failed) ...[
            _row(S.server, Icons.dns, h?.ok ?? false),
            _row(S.whisper, Icons.hearing, h?.whisper ?? false),
            _row(S.ollama, Icons.psychology, h?.ollama ?? false),
            _row(S.tts, Icons.record_voice_over, h?.tts ?? false),
            _row(S.upi, Icons.qr_code, h?.upiReady ?? false),
          ],
        ],
      ),
    );
  }
}
