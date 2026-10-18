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
import '../theme.dart';

class JobFormScreen extends StatefulWidget {
  /// 'intake' or 'quick'
  final String kind;

  /// When set, the form edits this job instead of creating a new one.
  final Job? job;
  const JobFormScreen({super.key, required this.kind, this.job});

  JobFormScreen.edit(Job this.job, {super.key}) : kind = job.kind;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  bool get _intake => widget.kind == 'intake';
  bool get _editing => widget.job != null;

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

  // Validation: field key -> message, shown in red under the field until it is fixed.
  final _errors = <String, String>{};
  final _keys = {
    for (final k in ['phone', 'name', 'appliance', 'amount']) k: GlobalKey(),
  };
  final _scroll = ScrollController();
  static final _mobile = RegExp(r'^[6-9]\d{9}$');

  Map<String, String> _validate() => {
    if (!_mobile.hasMatch(_phone.text.trim())) 'phone': S.errPhone,
    if (_name.text.trim().isEmpty) 'name': S.errName,
    if (_appliance == null) 'appliance': S.errAppliance,
    if (!_intake && _num(_finalAmount) == null) 'amount': S.errAmount,
  };

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    if (j != null) {
      final c = j.customer;
      _phone.text = c?.phone ?? '';
      _lookedUp = _phone
          .text; // don't show this customer as "returning" for their own job
      _name.text = c?.name ?? '';
      _village.text = c?.village ?? '';
      _appliance = j.appliance;
      _complaint.text = j.complaint ?? '';
      _diagnosis.text = j.diagnosis ?? '';
      _estimate.text = j.estimate?.toString() ?? '';
      _pickup = j.pickupDate == null ? null : DateTime.tryParse(j.pickupDate!);
      _workDone.text = j.workDone ?? '';
      _finalAmount.text = j.finalAmount?.toString() ?? '';
      _pay = j.paid ? (j.payMethod ?? 'cash') : 'none';
      _brand.text = j.brand ?? '';
      _model.text = j.model ?? '';
      _rating.text = j.rating ?? '';
      _serial.text = j.serial ?? '';
    }
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
    _scroll.dispose();
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
          _clearError('name');
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
        // Fields the voice just filled no longer need their red message.
        _errors.removeWhere((k, _) => !_validate().containsKey(k));
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
    final errors = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) {
      showMsg(context, S.fixErrors, error: true);
      // Scroll to the first field that needs fixing, in screen order. The list only
      // builds rows that are on screen, so if that field is off screen, go to the top
      // first (all checked fields but the amount are near the top), then to the field.
      final key = _keys[_keys.keys.firstWhere(errors.containsKey)]!;
      void reveal() {
        final ctx = key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.2,
          );
        }
      }

      if (key.currentContext != null) {
        reveal();
      } else {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
      }
      return;
    }
    String? nz(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final data = <String, dynamic>{
      'kind': widget.kind,
      'phone': phone,
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
    if (_editing) {
      await _saveEdit(data);
      return;
    }
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

  /// Edit mode: sends every field (cleared ones as null), then any newly taken photos.
  Future<void> _saveEdit(Map<String, dynamic> data) async {
    final id = widget.job!.id;
    final changes = Map<String, dynamic>.from(data)
      ..remove('kind')
      ..remove('transcript');
    try {
      await api.patchJob(id, changes);
      if (_machinePhoto != null ||
          _platePhoto != null ||
          (_intake && _customerPhoto != null)) {
        await api.uploadPhotos(
          id,
          machine: _machinePhoto?.path,
          plate: _platePhoto?.path,
          customer: _intake ? _customerPhoto?.path : null,
        );
      }
      if (!mounted) return;
      showMsg(context, S.changesSaved);
      Navigator.of(context).pop(true);
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

  /// [check] names a validated field: its label gets a " *", and its error shows under it.
  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    int lines = 1,
    List<TextInputFormatter>? fmt,
    String? check,
  }) {
    return Padding(
      key: check == null ? null : _keys[check],
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        minLines: lines,
        maxLines: lines == 1 ? 1 : 5,
        inputFormatters: fmt,
        onChanged: check == null ? null : (_) => _clearError(check),
        style: const TextStyle(fontSize: 22),
        decoration: InputDecoration(
          labelText: check == null ? label : '$label *',
          prefixIcon: Icon(icon),
          errorText: check == null ? null : _errors[check],
          errorStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _photoTile(
    String label,
    IconData icon,
    XFile? file,
    VoidCallback tap, {
    String? note,
    String? savedUrl,
  }) {
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: _busy ? null : tap,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null && savedUrl != null
                  ? AuthImage(savedUrl, width: double.infinity, height: 120)
                  : file == null
                  ? Center(
                      child: Icon(
                        icon,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
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
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
      color: AppTheme.isDark(context)
          ? const Color(0xFF1F3A2A)
          : const Color(0xFFE3F2E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
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
            onSelected: (_) => setState(() {
              _appliance = e.key;
              _errors.remove('appliance');
            }),
            // Selection is shown by colour alone; the icon stays instead of a tick.
            showCheckmark: false,
            avatar: Icon(
              S.applianceIcon(e.key),
              size: 26,
              color: _appliance == e.key
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 20,
                  color: _appliance == e.key
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
              ),
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }

  Widget _payChoice() {
    Widget chip(String v, String label, IconData icon) => ChoiceChip(
      selected: _pay == v,
      onSelected: (_) => setState(() => _pay = v),
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 26,
        color: _pay == v ? Theme.of(context).colorScheme.onPrimary : null,
      ),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            color: _pay == v ? Theme.of(context).colorScheme.onPrimary : null,
          ),
        ),
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
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
      appBar: AppBar(
        title: Text(
          _editing
              ? '${S.editJob} #${widget.job!.id}'
              : (_intake ? S.intakeTitle : S.quickTitle),
        ),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(14),
        children: [
          _field(
            _phone,
            S.phone,
            Icons.phone,
            type: TextInputType.number,
            fmt: [...digits, LengthLimitingTextInputFormatter(10)],
            check: 'phone',
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
                savedUrl: widget.job?.machinePhotoUrl,
              ),
              const SizedBox(width: 8),
              _photoTile(
                S.platePhoto,
                Icons.document_scanner,
                _platePhoto,
                _takePlate,
                savedUrl: widget.job?.platePhotoUrl,
              ),
              if (_intake) ...[
                const SizedBox(width: 8),
                _photoTile(
                  S.customerPhoto,
                  Icons.face,
                  _customerPhoto,
                  _takeCustomer,
                  note: S.customerPhotoNote,
                  savedUrl: widget.job?.customer?.photoUrl,
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
          _field(_name, S.name, Icons.person, check: 'name'),
          _field(_village, S.village, Icons.home_work),
          KeyedSubtree(
            key: _keys['appliance'],
            child: sectionTitle('${S.appliance} *', icon: Icons.build),
          ),
          _applianceGrid(),
          if (_errors['appliance'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                _errors['appliance']!,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
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
              check: 'amount',
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
