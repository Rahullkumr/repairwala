import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../strings.dart';
import '../widgets/common.dart';

class JobFormScreen extends StatefulWidget {
  /// 'intake' or 'quick'
  final String kind;
  const JobFormScreen({super.key, required this.kind});

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  bool get _intake => widget.kind == 'intake';

  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _complaint = TextEditingController();
  final _diagnosis = TextEditingController();
  final _estimate = TextEditingController();
  final _workDone = TextEditingController();
  final _finalAmount = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _rating = TextEditingController();
  final _serial = TextEditingController();
  final _transcript = TextEditingController();

  String? _appliance;
  DateTime? _pickup;
  String _pay = 'cash'; // cash | upi | none

  XFile? _machinePhoto, _platePhoto, _customerPhoto;
  final _picker = ImagePicker();

  CustomerLookup? _lookup;
  String _lookedUp = '';

  // voice
  final _rec = AudioRecorder();
  bool _recording = false;
  int _recSeconds = 0;
  Timer? _timer;
  String _busyText = '';
  bool _readingPlate = false;
  bool _saving = false;

  // Waiting on the laptop can take 10-60 s. Each wait has a number; "Cancel" bumps it,
  // so a late answer from a cancelled wait is ignored and the form stays usable.
  int _voiceOp = 0;
  int _plateOp = 0;
  DateTime _busySince = DateTime.now();
  DateTime _plateSince = DateTime.now();
  Timer? _tick; // redraws the elapsed seconds while something is waiting

  bool get _busy => _busyText.isNotEmpty || _saving;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhone);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_busyText.isNotEmpty || _readingPlate || _saving)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick?.cancel();
    _rec.dispose();
    for (final c in [
      _phone,
      _name,
      _village,
      _complaint,
      _diagnosis,
      _estimate,
      _workDone,
      _finalAmount,
      _brand,
      _model,
      _rating,
      _serial,
      _transcript,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- phone lookup ----------
  Future<void> _onPhone() async {
    final p = _phone.text.trim();
    if (p.length != 10 || p == _lookedUp) {
      if (p.length != 10 && _lookup != null) setState(() => _lookup = null);
      return;
    }
    _lookedUp = p;
    try {
      final r = await api.customerByPhone(p);
      if (!mounted || _phone.text.trim() != p) return;
      setState(() => _lookup = r.customer == null ? null : r);
      final c = r.customer;
      if (c != null) {
        if (_name.text.isEmpty && (c.name ?? '').isNotEmpty) {
          _name.text = c.name!;
        }
        if (_village.text.isEmpty && (c.village ?? '').isNotEmpty) {
          _village.text = c.village!;
        }
      }
    } catch (e) {
      _lookedUp = '';
      if (mounted) showError(context, e);
    }
  }

  // ---------- photos ----------
  Future<XFile?> _shoot(CameraDevice cam, {double maxWidth = 1600}) =>
      _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: cam,
        maxWidth: maxWidth,
        imageQuality: 80,
      );

  Future<void> _takeMachine() async {
    final f = await _shoot(CameraDevice.rear);
    if (f != null) setState(() => _machinePhoto = f);
  }

  Future<void> _takeCustomer() async {
    final f = await _shoot(CameraDevice.front);
    if (f != null) setState(() => _customerPhoto = f);
  }

  Future<void> _takePlate() async {
    final f = await _shoot(CameraDevice.rear, maxWidth: 1024);
    if (f == null) return;
    final op = ++_plateOp;
    setState(() {
      _platePhoto = f;
      _readingPlate = true;
      _plateSince = DateTime.now();
    });
    try {
      final p = await api.readPlate(f.path);
      if (!mounted || op != _plateOp) return;
      _fill(_brand, p.brand);
      _fill(_model, p.model);
      _fill(_rating, p.rating);
      _fill(_serial, p.serial);
    } catch (e) {
      if (mounted && op == _plateOp) showError(context, e);
    } finally {
      if (mounted && op == _plateOp) setState(() => _readingPlate = false);
    }
  }

  void _cancelPlate() {
    _plateOp++;
    setState(() => _readingPlate = false);
  }

  void _fill(TextEditingController c, String? v) {
    if (v != null && v.trim().isNotEmpty && c.text.trim().isEmpty) {
      c.text = v.trim();
    }
  }

  // ---------- voice ----------
  Future<void> _toggleRecord() async {
    if (_busy && !_recording) return;
    if (_recording) {
      await _stopAndProcess();
      return;
    }
    if (!await _rec.hasPermission()) {
      if (mounted) showMsg(context, S.micDenied, error: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/say_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _recSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recSeconds++);
    });
    setState(() => _recording = true);
  }

  void _setBusy(String text) => setState(() {
    _busyText = text;
    _busySince = DateTime.now();
  });

  void _endBusy(int op) {
    if (mounted && op == _voiceOp) setState(() => _busyText = '');
  }

  void _cancelVoice() {
    _voiceOp++;
    setState(() => _busyText = '');
  }

  Future<void> _stopAndProcess() async {
    _timer?.cancel();
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path == null) return;
    final op = ++_voiceOp;
    _setBusy(S.listening);
    try {
      final text = await api.transcribe(path);
      if (!mounted || op != _voiceOp) return;
      _transcript.text = text;
      if (text.trim().isNotEmpty) await _parse(text, op: op);
    } catch (e) {
      if (mounted && op == _voiceOp) showError(context, e);
    } finally {
      _endBusy(op);
    }
  }

  /// Fills the form from the spoken text. Clears its own progress message when done,
  /// whether it was started by the mic or by the re-understand button.
  Future<void> _parse(String text, {int? op}) async {
    op ??= ++_voiceOp;
    _setBusy(S.understanding);
    try {
      final p = await api.parseIntake(text, widget.kind);
      if (!mounted || op != _voiceOp) return;
      setState(() {
        _fill(_name, p.name);
        _fill(_village, p.village);
        _fill(_complaint, p.complaint);
        _fill(_diagnosis, p.diagnosis);
        _fill(_workDone, p.workDone);
        if (p.estimate != null && _estimate.text.trim().isEmpty) {
          _estimate.text = '${p.estimate}';
        }
        if (p.finalAmount != null && _finalAmount.text.trim().isEmpty) {
          _finalAmount.text = '${p.finalAmount}';
        }
        if (_appliance == null &&
            p.appliance != null &&
            S.appliances.containsKey(p.appliance)) {
          _appliance = p.appliance;
        }
        if (_pickup == null && p.pickupDate != null) {
          _pickup = DateTime.tryParse(p.pickupDate!);
        }
      });
    } catch (e) {
      if (mounted && op == _voiceOp) showError(context, e);
    } finally {
      _endBusy(op);
    }
  }

  // ---------- save ----------
  int? _num(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    final phone = _phone.text.trim();
    if (_intake && phone.length != 10) {
      showMsg(context, S.phoneNeeded, error: true);
      return;
    }
    if (phone.isNotEmpty && phone.length != 10) {
      showMsg(context, S.phoneNeeded, error: true);
      return;
    }
    String? nz(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final data = <String, dynamic>{
      'kind': widget.kind,
      if (phone.isNotEmpty) 'phone': phone,
      'name': nz(_name),
      'village': nz(_village),
      'appliance': _appliance,
      'brand': nz(_brand),
      'model': nz(_model),
      'rating': nz(_rating),
      'serial': nz(_serial),
      'complaint': nz(_complaint),
      'diagnosis': nz(_diagnosis),
      'transcript': nz(_transcript),
      if (_intake) 'estimate': _num(_estimate),
      if (_intake && _pickup != null) 'pickup_date': ymd(_pickup!),
      if (!_intake) ...{
        'work_done': nz(_workDone),
        'final_amount': _num(_finalAmount),
        'paid': _pay != 'none',
        'pay_method': _pay == 'none' ? null : _pay,
      },
    };
    setState(() {
      _saving = true;
      _busySince = DateTime.now();
    });
    try {
      final job = await api.createJob(
        data,
        machine: _machinePhoto?.path,
        plate: _platePhoto?.path,
        customer: _intake ? _customerPhoto?.path : null,
      );
      if (!mounted) return;
      if (_intake) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => _JobNumberScreen(jobId: job.id)),
        );
      } else {
        final m = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        m.showSnackBar(
          SnackBar(
            content: Text(S.quickSaved, style: TextStyle(fontSize: 20)),
            backgroundColor: kGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  // ---------- UI ----------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _pickup ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _pickup = d);
  }

  void _quickDate(int days) {
    final n = DateTime.now();
    setState(() => _pickup = DateTime(n.year, n.month, n.day + days));
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    int lines = 1,
    List<TextInputFormatter>? fmt,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 5,
        inputFormatters: fmt,
        style: const TextStyle(fontSize: 22),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _photoTile(
    String label,
    IconData icon,
    XFile? file,
    VoidCallback tap, {
    String? note,
  }) {
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: _busy ? null : tap,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kGreen, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? Center(child: Icon(icon, size: 48, color: kGreen))
                  : Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (note != null)
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
        ],
      ),
    );
  }

  Widget _mic() {
    final c = _recording ? kRed : kGreen;
    return Column(
      children: [
        Text(
          _intake ? S.hintIntake : S.hintQuick,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _toggleRecord,
          child: _Pulse(
            active: _recording,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _recording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _recording
                        ? '${S.stopSpeak}  ${(_recSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recSeconds % 60).toString().padLeft(2, '0')}'
                        : S.speak,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_busyText.isNotEmpty)
          _progress(_busyText, since: _busySince, onCancel: _cancelVoice),
      ],
    );
  }

  Widget _progress(String t, {DateTime? since, VoidCallback? onCancel}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(),
            ),
            Text(
              since == null ? t : '$t ${S.secs(_elapsed(since))}',
              style: const TextStyle(fontSize: 22),
            ),
            if (onCancel != null)
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close),
                label: Text(S.cancelWait, style: const TextStyle(fontSize: 20)),
              ),
          ],
        ),
      );

  int _elapsed(DateTime since) => DateTime.now().difference(since).inSeconds;

  Widget _customerBanner() {
    final l = _lookup;
    if (l == null || l.customer == null) return const SizedBox.shrink();
    final c = l.customer!;
    final recent = l.jobs.take(3).toList();
    return Card(
      color: const Color(0xFFE3F2E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: kGreen, size: 28),
                const SizedBox(width: 8),
                Text(
                  S.oldCustomer,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              [
                c.name ?? '',
                c.village ?? '',
              ].where((e) => e.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 20),
            ),
            if (l.jobs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${S.pastJobs}: ${l.jobs.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final j in recent)
                Text(
                  '#${j.id} · ${S.applianceLabel(j.appliance)} · ${fmtDate(j.createdAt)} · ${S.statusLabel(j.status)}',
                  style: const TextStyle(fontSize: 17),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _applianceGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in S.appliances.entries)
          ChoiceChip(
            selected: _appliance == e.key,
            onSelected: (_) => setState(() => _appliance = e.key),
            avatar: Icon(S.applianceIcon(e.key), size: 26),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(e.value, style: const TextStyle(fontSize: 20)),
            ),
            selectedColor: const Color(0xFFB7D9B0),
          ),
      ],
    );
  }

  Widget _payChoice() {
    Widget chip(String v, String label, IconData icon) => ChoiceChip(
      selected: _pay == v,
      onSelected: (_) => setState(() => _pay = v),
      avatar: Icon(icon, size: 26),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
      selectedColor: const Color(0xFFB7D9B0),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('cash', S.cash, Icons.payments),
        chip('upi', S.upiPay, Icons.qr_code),
        chip('none', S.notYet, Icons.hourglass_empty),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: Text(_intake ? S.intakeTitle : S.quickTitle)),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _field(
            _phone,
            S.phone,
            Icons.phone,
            type: TextInputType.number,
            fmt: [...digits, LengthLimitingTextInputFormatter(10)],
          ),
          _customerBanner(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _photoTile(
                S.machinePhoto,
                Icons.photo_camera,
                _machinePhoto,
                _takeMachine,
              ),
              const SizedBox(width: 8),
              _photoTile(
                S.platePhoto,
                Icons.document_scanner,
                _platePhoto,
                _takePlate,
              ),
              if (_intake) ...[
                const SizedBox(width: 8),
                _photoTile(
                  S.customerPhoto,
                  Icons.face,
                  _customerPhoto,
                  _takeCustomer,
                  note: S.customerPhotoNote,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _mic(),
          const SizedBox(height: 12),
          if (_transcript.text.isNotEmpty || _busyText.isNotEmpty)
            _field(
              _transcript,
              S.transcript,
              Icons.subtitles,
              type: TextInputType.multiline,
              lines: 2,
            ),
          if (_transcript.text.isNotEmpty && _busyText.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BigButton(
                icon: Icons.auto_fix_high,
                label: S.reparse,
                outlined: true,
                onPressed: _busy ? null : () => _parse(_transcript.text),
              ),
            ),
          const Divider(height: 24),
          _field(_name, S.name, Icons.person),
          _field(_village, S.village, Icons.home_work),
          sectionTitle(S.appliance, icon: Icons.build),
          _applianceGrid(),
          const SizedBox(height: 16),
          _field(_complaint, S.complaint, Icons.report_problem, lines: 2),
          _field(_diagnosis, S.diagnosis, Icons.troubleshoot, lines: 2),
          if (_intake) ...[
            _field(
              _estimate,
              S.estimate,
              Icons.currency_rupee,
              type: TextInputType.number,
              fmt: digits,
            ),
            sectionTitle(S.pickupDate, icon: Icons.event),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in {
                  S.today: 0,
                  S.tomorrow: 1,
                  S.dayAfter: 2,
                }.entries)
                  ActionChip(
                    avatar: const Icon(Icons.event_available),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(e.key, style: const TextStyle(fontSize: 20)),
                    ),
                    onPressed: () => _quickDate(e.value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            BigButton(
              icon: Icons.calendar_month,
              label: _pickup == null ? S.pickDate : fmtDate(ymd(_pickup!)),
              outlined: true,
              onPressed: _pickDate,
            ),
          ] else ...[
            _field(_workDone, S.workDone, Icons.handyman, lines: 2),
            _field(
              _finalAmount,
              S.finalAmount,
              Icons.currency_rupee,
              type: TextInputType.number,
              fmt: digits,
            ),
            sectionTitle(S.paidQ, icon: Icons.payments),
            _payChoice(),
          ],
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline, size: 28),
              initiallyExpanded: false,
              title: Text(
                S.machineInfo,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              subtitle: _readingPlate
                  ? Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${S.readingPlate} ${S.secs(_elapsed(_plateSince))}',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        IconButton(
                          tooltip: S.cancelWait,
                          icon: const Icon(Icons.close),
                          onPressed: _cancelPlate,
                        ),
                      ],
                    )
                  : null,
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [
                _field(_brand, S.brand, Icons.sell),
                _field(_model, S.model, Icons.tag),
                _field(_rating, S.rating, Icons.bolt),
                _field(_serial, S.serial, Icons.numbers),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_saving)
            _progress(S.saving, since: _busySince)
          else
            BigButton(
              icon: Icons.check_circle,
              label: S.saveJob,
              onPressed: _busy ? null : _save,
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final bool active;
  final Widget child;
  const _Pulse({required this.active, required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) =>
          Transform.scale(scale: 1 + 0.04 * _c.value, child: child),
      child: widget.child,
    );
  }
}

class _JobNumberScreen extends StatelessWidget {
  final int jobId;
  const _JobNumberScreen({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 80),
              const SizedBox(height: 16),
              FittedBox(
                child: Text(
                  '#$jobId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 140,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.writeNumber,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kGreen,
                  minimumSize: const Size.fromHeight(72),
                  textStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(S.ok),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
