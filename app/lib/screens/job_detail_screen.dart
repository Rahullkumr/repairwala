import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../strings.dart';
import '../widgets/common.dart';
import 'notify_screen.dart';
import 'job_form_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await api.getJob(widget.jobId);
      if (mounted)
        setState(() {
          _job = j;
          _error = null;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : S.connectError);
      }
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----- actions -----
  Future<void> _markFixed({bool again = false}) async {
    final j = _job!;
    final amount = TextEditingController(
      text: '${j.finalAmount ?? j.estimate ?? ''}',
    );
    final work = TextEditingController(text: j.workDone ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                labelText: S.finalAmount,
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: work,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                labelText: S.workDone,
                prefixIcon: Icon(Icons.handyman),
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              icon: Icons.check_circle,
              label: again ? S.resend : S.fixed,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await api.notify(
        j.id,
        finalAmount: int.tryParse(amount.text.trim()),
        workDone: work.text,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotifyScreen(jobId: j.id, result: res),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delivered() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.paidQ, style: TextStyle(fontSize: 26)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BigButton(
              icon: Icons.payments,
              label: S.cash,
              onPressed: () => Navigator.pop(ctx, 'cash'),
            ),
            const SizedBox(height: 10),
            BigButton(
              icon: Icons.qr_code,
              label: S.upiPay,
              onPressed: () => Navigator.pop(ctx, 'upi'),
            ),
            const SizedBox(height: 10),
            BigButton(
              icon: Icons.hourglass_empty,
              label: S.notYet,
              outlined: true,
              onPressed: () => Navigator.pop(ctx, 'none'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _run(
      () => api
          .patchJob(_job!.id, {
            'status': 'delivered',
            'paid': choice != 'none',
            'pay_method': choice == 'none' ? null : choice,
          })
          .then((_) {}),
    );
  }

  Future<void> _returned() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.confirmReturn, style: TextStyle(fontSize: 24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.no, style: TextStyle(fontSize: 22)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.yes, style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => api.patchJob(_job!.id, {'status': 'returned'}).then((_) {}),
    );
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => JobFormScreen.edit(_job!)));
    if (changed == true) await _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.confirmDelete, style: const TextStyle(fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.no, style: const TextStyle(fontSize: 22)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.deleteJob, style: const TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.deleteJob(_job!.id);
      if (!mounted) return;
      showMsg(context, S.deleted);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _call(String phone) async {
    try {
      await launchUrl(Uri.parse('tel:$phone'));
    } catch (_) {}
  }

  // ----- UI -----
  Widget _kv(IconData icon, String k, String? v) {
    if (v == null || v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$k: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: v),
                ],
              ),
              style: const TextStyle(fontSize: 21),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(String? url) {
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => FullPhotoScreen(url))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AuthImage(url, width: 140, height: 140),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    return Scaffold(
      appBar: AppBar(
        title: Text(j == null ? S.jobDetail : '#${j.id}'),
        actions: [
          if (j != null) ...[
            IconButton(
              iconSize: 30,
              tooltip: S.edit,
              icon: const Icon(Icons.edit),
              onPressed: _busy ? null : _edit,
            ),
            IconButton(
              iconSize: 30,
              tooltip: S.deleteJob,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
          ],
        ],
      ),
      body: j == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(height: 16),
                          BigButton(
                            icon: Icons.refresh,
                            label: S.retry,
                            onPressed: _load,
                          ),
                        ],
                      ),
                    ),
            )
          : _content(j),
    );
  }

  Widget _content(Job j) {
    final c = j.customer;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              '#${j.id}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Icon(S.applianceIcon(j.appliance), size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                S.applianceLabel(j.appliance),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            StatusChip(j.status),
          ],
        ),
        const SizedBox(height: 12),
        if (j.machinePhotoUrl != null ||
            j.platePhotoUrl != null ||
            c?.photoUrl != null)
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _photo(j.machinePhotoUrl),
                _photo(j.platePhotoUrl),
                _photo(c?.photoUrl),
              ],
            ),
          ),
        sectionTitle(S.name, icon: Icons.person),
        _kv(Icons.person, S.name, c?.name),
        _kv(Icons.home_work, S.village, c?.village),
        _kv(Icons.phone, S.phone.split(' ').first, c?.phone),
        if (c != null && c.phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: BigButton(
              icon: Icons.call,
              label: S.call,
              color: const Color(0xFF1B7F3B),
              onPressed: () => _call(c.phone),
            ),
          ),
        const Divider(height: 28),
        _kv(Icons.report_problem, S.complaint, j.complaint),
        _kv(Icons.troubleshoot, S.diagnosis, j.diagnosis),
        _kv(Icons.handyman, S.workDone, j.workDone),
        _kv(
          Icons.currency_rupee,
          S.estimate,
          j.estimate == null ? null : '₹${j.estimate}',
        ),
        _kv(
          Icons.currency_rupee,
          S.finalAmount,
          j.finalAmount == null ? null : '₹${j.finalAmount}',
        ),
        _kv(
          Icons.event,
          S.pickupDate,
          j.pickupDate == null ? null : fmtDate(j.pickupDate),
        ),
        _kv(Icons.sell, S.brand, j.brand),
        _kv(Icons.tag, S.model, j.model),
        _kv(Icons.bolt, S.rating, j.rating),
        _kv(Icons.numbers, S.serial, j.serial),
        if (j.status == 'delivered')
          _kv(
            Icons.payments,
            S.paidQ,
            j.paid
                ? '${S.paid} (${j.payMethod == 'upi' ? S.upiPay : S.cash})'
                : S.notPaid,
          ),
        const SizedBox(height: 16),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (!_busy) ..._actions(j),
        if (j.history.isNotEmpty) ...[
          sectionTitle(S.history, icon: Icons.history),
          for (final h in j.history)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(S.applianceIcon(h.appliance), size: 32),
                title: Text(
                  '#${h.id} · ${S.applianceLabel(h.appliance)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${fmtDate(h.createdAt)} · ${S.statusLabel(h.status)}',
                  style: const TextStyle(fontSize: 17),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JobDetailScreen(jobId: h.id),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  List<Widget> _actions(Job j) {
    const gap = SizedBox(height: 12);
    final out = <Widget>[];
    if (j.status == 'received') {
      out.add(
        BigButton(
          icon: Icons.check_circle,
          label: S.fixed,
          color: const Color(0xFF1B7F3B),
          onPressed: _markFixed,
        ),
      );
    }
    if (j.status == 'repaired') {
      out.add(
        BigButton(
          icon: Icons.handshake,
          label: S.handedOver,
          color: const Color(0xFF1B7F3B),
          onPressed: _delivered,
        ),
      );
      out.add(gap);
      out.add(
        BigButton(
          icon: Icons.send,
          label: S.resend,
          outlined: true,
          onPressed: () => _markFixed(again: true),
        ),
      );
    }
    if (j.isOpen) {
      out.add(const SizedBox(height: 20));
      out.add(
        TextButton.icon(
          onPressed: _returned,
          icon: const Icon(Icons.undo),
          label: Text(S.cannotFix, style: TextStyle(fontSize: 18)),
        ),
      );
    }
    return out;
  }
}
