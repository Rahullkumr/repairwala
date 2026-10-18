import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _channel = MethodChannel('repairwala/whatsapp');

/// Try to send straight into the customer's WhatsApp chat; fall back to the
/// system share sheet if WhatsApp (or the channel) is not available.
Future<void> shareToChat({
  required String? phone,
  required String text,
  required List<String> paths,
}) async {
  if (phone != null && phone.isNotEmpty) {
    try {
      final ok = await _channel.invokeMethod<bool>('shareToChat', {
        'phone': phone,
        'text': text,
        'paths': paths,
      });
      if (ok == true) return;
    } catch (_) {}
  }
  await SharePlus.instance.share(ShareParams(
    text: text,
    files: paths.map((p) => XFile(p)).toList(),
  ));
}

/// Open wa.me with only the text (no attachments).
Future<bool> openWaText(String? phone, String text) async {
  final p = (phone ?? '').isEmpty ? '' : phone!;
  final uri = Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}');
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
