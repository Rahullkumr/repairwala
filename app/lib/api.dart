import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

class Customer {
  final int id;
  final String phone;
  final String? name;
  final String? village;
  final String? photoUrl;
  Customer({
    required this.id,
    required this.phone,
    this.name,
    this.village,
    this.photoUrl,
  });
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: _int(j['id']) ?? 0,
        phone: (j['phone'] ?? '').toString(),
        name: j['name'] as String?,
        village: j['village'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

class Job {
  final int id;
  final Customer? customer;
  final String kind;
  final String? appliance, brand, model, rating, serial;
  final String? complaint, diagnosis, workDone;
  final int? estimate, finalAmount;
  final String? pickupDate;
  final String status;
  final bool paid;
  final String? payMethod;
  final String? transcript;
  final String? machinePhotoUrl, platePhotoUrl;
  final String? createdAt, repairedAt, deliveredAt, notifiedAt;
  final List<Job> history;

  Job({
    required this.id,
    this.customer,
    this.kind = 'intake',
    this.appliance,
    this.brand,
    this.model,
    this.rating,
    this.serial,
    this.complaint,
    this.diagnosis,
    this.workDone,
    this.estimate,
    this.finalAmount,
    this.pickupDate,
    this.status = 'received',
    this.paid = false,
    this.payMethod,
    this.transcript,
    this.machinePhotoUrl,
    this.platePhotoUrl,
    this.createdAt,
    this.repairedAt,
    this.deliveredAt,
    this.notifiedAt,
    this.history = const [],
  });

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: _int(j['id']) ?? 0,
        customer: j['customer'] is Map<String, dynamic>
            ? Customer.fromJson(j['customer'] as Map<String, dynamic>)
            : null,
        kind: (j['kind'] ?? 'intake').toString(),
        appliance: j['appliance'] as String?,
        brand: j['brand'] as String?,
        model: j['model'] as String?,
        rating: j['rating'] as String?,
        serial: j['serial'] as String?,
        complaint: j['complaint'] as String?,
        diagnosis: j['diagnosis'] as String?,
        workDone: j['work_done'] as String?,
        estimate: _int(j['estimate']),
        finalAmount: _int(j['final_amount']),
        pickupDate: j['pickup_date'] as String?,
        status: (j['status'] ?? 'received').toString(),
        paid: j['paid'] == true || j['paid'] == 1,
        payMethod: j['pay_method'] as String?,
        transcript: j['transcript'] as String?,
        machinePhotoUrl: j['machine_photo_url'] as String?,
        platePhotoUrl: j['plate_photo_url'] as String?,
        createdAt: j['created_at'] as String?,
        repairedAt: j['repaired_at'] as String?,
        deliveredAt: j['delivered_at'] as String?,
        notifiedAt: j['notified_at'] as String?,
        history: (j['history'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Job.fromJson)
            .toList(),
      );

  bool get isOpen => status == 'received' || status == 'repaired';

  /// -1 overdue, 0 today, 1 later, null if no date / not open.
  int? get pickupState {
    if (!isOpen || pickupDate == null) return null;
    final d = DateTime.tryParse(pickupDate!);
    if (d == null) return null;
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final c = d.difference(t).inDays;
    if (c < 0) return -1;
    if (c == 0) return 0;
    return 1;
  }
}

class Health {
  final bool ok, whisper, ollama, tts, upiReady;
  final String? shopName;
  Health(this.ok, this.whisper, this.ollama, this.tts, this.upiReady,
      this.shopName);
  factory Health.fromJson(Map<String, dynamic> j) => Health(
        j['ok'] == true,
        j['whisper'] == true,
        j['ollama'] == true,
        j['tts'] == true,
        j['upi_ready'] == true,
        j['shop_name'] as String?,
      );
}

class ParsedIntake {
  final String? name, village, appliance, complaint, diagnosis, workDone;
  final int? estimate, finalAmount;
  final String? pickupDate;
  ParsedIntake.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String?,
        village = j['village'] as String?,
        appliance = j['appliance'] as String?,
        complaint = j['complaint'] as String?,
        diagnosis = j['diagnosis'] as String?,
        workDone = j['work_done'] as String?,
        estimate = _int(j['estimate']),
        finalAmount = _int(j['final_amount']),
        pickupDate = j['pickup_date'] as String?;
}

class PlateInfo {
  final String? brand, model, rating, serial;
  PlateInfo.fromJson(Map<String, dynamic> j)
      : brand = j['brand'] as String?,
        model = j['model'] as String?,
        rating = j['rating'] as String?,
        serial = j['serial'] as String?;
}

class NotifyResult {
  final String text;
  final String? speech, voiceUrl, qrUrl, upiLink, waPhone;
  NotifyResult.fromJson(Map<String, dynamic> j)
      : text = (j['text'] ?? '').toString(),
        speech = j['speech'] as String?,
        voiceUrl = j['voice_url'] as String?,
        qrUrl = j['qr_url'] as String?,
        upiLink = j['upi_link'] as String?,
        waPhone = j['wa_phone'] as String?;
}

class CustomerLookup {
  final Customer? customer;
  final List<Job> jobs;
  CustomerLookup(this.customer, this.jobs);
}

class Api {
  String baseUrl = '';
  String token = '';

  bool get configured => baseUrl.isNotEmpty && token.isNotEmpty;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    baseUrl = p.getString('base_url') ?? '';
    token = p.getString('token') ?? '';
  }

  Future<void> saveSettings(String url, String tok) async {
    var u = url.trim();
    if (u.isNotEmpty && !u.startsWith('http')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    baseUrl = u;
    token = tok.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('base_url', baseUrl);
    await p.setString('token', token);
  }

  Map<String, String> get headers => {'X-Shop-Token': token};

  String fileUrl(String rel) => rel.startsWith('http')
      ? rel
      : '$baseUrl${rel.startsWith('/') ? '' : '/'}$rel';

  Uri _uri(String path, [Map<String, String>? q]) {
    if (!configured) throw ApiException(S.needSettings);
    final u = Uri.parse('$baseUrl$path');
    return q == null ? u : u.replace(queryParameters: q);
  }

  Future<dynamic> _run(Future<http.Response> Function() f,
      {Duration timeout = const Duration(seconds: 20)}) async {
    try {
      final r = await f().timeout(timeout);
      dynamic body;
      try {
        body = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        body = null;
      }
      if (r.statusCode >= 400) {
        final msg = body is Map && body['error'] != null
            ? body['error'].toString()
            : 'Error ${r.statusCode}';
        throw ApiException(msg);
      }
      return body;
    } on TimeoutException {
      throw ApiException(S.timeoutError);
    } on SocketException {
      throw ApiException(S.connectError);
    } on http.ClientException {
      throw ApiException(S.connectError);
    } on FormatException {
      throw ApiException(S.connectError);
    }
  }

  Future<dynamic> _multipart(
    String path,
    Map<String, String> fields,
    Map<String, String> files, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    return _run(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      req.headers.addAll(headers);
      req.fields.addAll(fields);
      for (final e in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
      }
      return http.Response.fromStream(await req.send());
    }, timeout: timeout);
  }

  Future<Health> health() async {
    final b = await _run(() => http.get(_uri('/api/health'), headers: headers),
        timeout: const Duration(seconds: 8));
    return Health.fromJson(b as Map<String, dynamic>);
  }

  Future<String> transcribe(String wavPath) async {
    final b = await _multipart('/api/transcribe', {}, {'audio': wavPath});
    return ((b as Map)['text'] ?? '').toString();
  }

  Future<ParsedIntake> parseIntake(String text, String kind) async {
    final b = await _run(
      () => http.post(_uri('/api/parse-intake'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'kind': kind})),
      timeout: const Duration(seconds: 120),
    );
    return ParsedIntake.fromJson(b as Map<String, dynamic>);
  }

  Future<PlateInfo> readPlate(String jpgPath) async {
    final b = await _multipart('/api/read-plate', {}, {'photo': jpgPath});
    return PlateInfo.fromJson(b as Map<String, dynamic>);
  }

  Future<CustomerLookup> customerByPhone(String phone) async {
    final b = await _run(
        () => http.get(_uri('/api/customers/by-phone/$phone'),
            headers: headers),
        timeout: const Duration(seconds: 10));
    final m = b as Map<String, dynamic>;
    return CustomerLookup(
      m['customer'] is Map<String, dynamic>
          ? Customer.fromJson(m['customer'] as Map<String, dynamic>)
          : null,
      (m['jobs'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList(),
    );
  }

  Future<Job> createJob(Map<String, dynamic> data,
      {String? machine, String? plate, String? customer}) async {
    final files = <String, String>{
      if (machine != null) 'machine_photo': machine,
      if (plate != null) 'plate_photo': plate,
      if (customer != null) 'customer_photo': customer,
    };
    final b = await _multipart('/api/jobs', {'data': jsonEncode(data)}, files);
    return Job.fromJson(b as Map<String, dynamic>);
  }

  Future<List<Job>> listJobs(String status, String q) async {
    final b = await _run(
        () => http.get(
            _uri('/api/jobs',
                {'status': status, if (q.trim().isNotEmpty) 'q': q.trim()}),
            headers: headers),
        timeout: const Duration(seconds: 15));
    return ((b as Map)['jobs'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Job.fromJson)
        .toList();
  }

  Future<Job> getJob(int id) async {
    final b =
        await _run(() => http.get(_uri('/api/jobs/$id'), headers: headers));
    return Job.fromJson(b as Map<String, dynamic>);
  }

  Future<Job> patchJob(int id, Map<String, dynamic> data) async {
    final b = await _run(() => http.patch(_uri('/api/jobs/$id'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(data)));
    return Job.fromJson(b as Map<String, dynamic>);
  }

  Future<NotifyResult> notify(int id,
      {int? finalAmount, String? workDone}) async {
    final b = await _run(
      () => http.post(_uri('/api/jobs/$id/notify'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            if (finalAmount != null) 'final_amount': finalAmount,
            if (workDone != null && workDone.trim().isNotEmpty)
              'work_done': workDone.trim(),
          })),
      timeout: const Duration(seconds: 120),
    );
    return NotifyResult.fromJson(b as Map<String, dynamic>);
  }

  /// Download a server file (with token header) to [destPath].
  Future<File> download(String rel, String destPath) async {
    try {
      final r = await http
          .get(Uri.parse(fileUrl(rel)), headers: headers)
          .timeout(const Duration(seconds: 60));
      if (r.statusCode >= 400) throw ApiException('Error ${r.statusCode}');
      final f = File(destPath);
      await f.writeAsBytes(r.bodyBytes);
      return f;
    } on TimeoutException {
      throw ApiException(S.timeoutError);
    } on SocketException {
      throw ApiException(S.connectError);
    } on http.ClientException {
      throw ApiException(S.connectError);
    }
  }
}

final api = Api();
