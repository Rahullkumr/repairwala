import 'package:flutter/material.dart';

import '../api.dart';
import '../strings.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

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
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(
              labelText: S.serverAddress,
              prefixIcon: Icon(Icons.wifi),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _token,
            style: const TextStyle(fontSize: 22),
            decoration: const InputDecoration(
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
