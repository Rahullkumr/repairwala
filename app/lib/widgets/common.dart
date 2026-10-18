import 'package:flutter/material.dart';

import '../api.dart';
import '../strings.dart';

const kGreen = Color(0xFF2E4742);
const kOrange = Color(0xFFD96C00);
const kRed = Color(0xFFB3261E);

void showMsg(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 20)),
      backgroundColor: error ? kRed : kGreen,
      duration: Duration(seconds: error ? 5 : 3),
    ),
  );
}

void showError(BuildContext context, Object e) {
  final msg = e is ApiException ? e.message : S.connectError;
  showMsg(context, msg, error: true);
}

/// Big filled button with icon + label (min height 64).
class BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool outlined;
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    // Hindi labels wrap nicely onto two lines ("मशीन / जमा करें"); short English labels
    // look broken when wrapped ("New / job"), so in English keep them on one line,
    // with less side padding and shrinking a little if a half-width button is too narrow.
    final english = !S.isHindi;
    final style =
        (outlined ? OutlinedButton.styleFrom : FilledButton.styleFrom)(
          minimumSize: const Size.fromHeight(64),
          padding: english ? const EdgeInsets.symmetric(horizontal: 12) : null,
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: outlined ? null : color,
          foregroundColor: outlined ? color : null,
        );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30),
        const SizedBox(width: 10),
        Flexible(
          child: english
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, maxLines: 1),
                )
              : Text(label, textAlign: TextAlign.center),
        ),
      ],
    );
    return outlined
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : FilledButton(onPressed: onPressed, style: style, child: child);
  }
}

/// Network image carrying the shop token header.
class AuthImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final BoxFit fit;
  const AuthImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      api.fileUrl(url!),
      headers: api.headers,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.black12,
        child: const Icon(Icons.broken_image, size: 40),
      ),
    );
  }
}

class FullPhotoScreen extends StatelessWidget {
  final String url;
  const FullPhotoScreen(this.url, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(),
    body: Center(
      child: InteractiveViewer(child: AuthImage(url, fit: BoxFit.contain)),
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    Color c;
    IconData i;
    switch (status) {
      case 'received':
        c = kOrange;
        i = Icons.inbox;
        break;
      case 'repaired':
        c = const Color(0xFF1B7F3B);
        i = Icons.check_circle;
        break;
      case 'delivered':
        c = Colors.blueGrey.shade700;
        i = Icons.handshake;
        break;
      default:
        c = Colors.brown;
        i = Icons.undo;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            S.statusLabel(status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String fmtDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day}/${d.month}/${d.year}';
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget sectionTitle(String t, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 8),
  child: Row(
    children: [
      if (icon != null) ...[Icon(icon, size: 26), const SizedBox(width: 8)],
      Text(
        t,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    ],
  ),
);

/// Compact card for a job (used on home and in history lists).
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final st = job.pickupState;
    Widget? pickup;
    if (job.pickupDate != null) {
      Color? c; // default text colour, light or dark
      String t = '${S.pickupDate}: ${fmtDate(job.pickupDate)}';
      if (st == -1) {
        c = kRed;
        t = '${S.overdue} · ${fmtDate(job.pickupDate)}';
      } else if (st == 0) {
        c = kOrange;
        t = '${S.today} · ${fmtDate(job.pickupDate)}';
      }
      pickup = Row(
        children: [
          Icon(Icons.event, size: 22, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              t,
              style: TextStyle(
                fontSize: 18,
                color: c,
                fontWeight: st == null || st > 0
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    final who = [
      if ((job.customer?.name ?? '').isNotEmpty) job.customer!.name!,
      if ((job.customer?.village ?? '').isNotEmpty) job.customer!.village!,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    '#${job.id}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Icon(S.applianceIcon(job.appliance), size: 30),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.applianceLabel(job.appliance),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (who.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              who,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                    if (pickup != null) pickup,
                    const SizedBox(height: 6),
                    StatusChip(job.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
