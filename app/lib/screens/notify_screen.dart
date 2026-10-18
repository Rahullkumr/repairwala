import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../api.dart';
import '../strings.dart';
import '../whatsapp.dart';
import '../widgets/common.dart';

/// Preview of the customer message + QR + voice note, with WhatsApp send.
class NotifyScreen extends StatefulWidget {
  final int jobId;
  final NotifyResult result;
  const NotifyScreen({super.key, required this.jobId, required this.result});

  @override
  State<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends State<NotifyScreen> {
  final _player = AudioPlayer();
  File? _qr, _voice;
  bool _preparing = true;
  bool _playing = false;

  NotifyResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _prepare();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final dir = await getTemporaryDirectory();
      if (r.qrUrl != null) {
        _qr = await api.download(r.qrUrl!, '${dir.path}/job${widget.jobId}-qr.png');
      }
      if (r.voiceUrl != null) {
        _voice = await api.download(
            r.voiceUrl!, '${dir.path}/job${widget.jobId}-ready.mp3');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _togglePlay() async {
    if (_voice == null) return;
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
    } else {
      await _player.play(DeviceFileSource(_voice!.path));
      setState(() => _playing = true);
    }
  }

  Future<void> _send() async {
    final paths = [
      if (_qr != null) _qr!.path,
      if (_voice != null) _voice!.path,
    ];
    try {
      await shareToChat(phone: r.waPhone, text: r.text, paths: paths);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    }
  }

  Future<void> _textOnly() async {
    final ok = await openWaText(r.waPhone, r.text);
    if (!ok && mounted) showMsg(context, S.connectError, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.messagePreview)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(r.text, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(height: 16),
          if (_preparing)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              SizedBox(
                  width: 28, height: 28, child: CircularProgressIndicator()),
              SizedBox(width: 12),
              Text(S.preparing, style: TextStyle(fontSize: 22)),
            ]),
          if (_qr != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Image.file(_qr!, width: 260, height: 260),
              ),
            ),
          if (_voice != null) ...[
            const SizedBox(height: 16),
            BigButton(
              icon: _playing ? Icons.stop_circle : Icons.play_circle,
              label: _playing ? S.stopVoice : S.playVoice,
              outlined: true,
              onPressed: _togglePlay,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 88,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B7F3B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              icon: const Icon(Icons.send, size: 36),
              label: const Text(S.sendWhatsapp),
              onPressed: _preparing ? null : _send,
            ),
          ),
          const SizedBox(height: 14),
          if (r.waPhone != null)
            BigButton(
              icon: Icons.chat,
              label: S.sendMessageOnly,
              outlined: true,
              onPressed: _textOnly,
            ),
        ],
      ),
    );
  }
}
