import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../strings.dart';
import '../widgets/common.dart';
import 'job_detail_screen.dart';
import 'job_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
  final _search = TextEditingController();
  Timer? _debounce;
  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await api.listJobs(
          _tabs.index == 0 ? 'open' : 'done', _search.text);
      if (mounted) setState(() => _jobs = j);
    } catch (e) {
      if (mounted) {
        setState(() {
          _jobs = [];
          _error = e is ApiException ? e.message : S.connectError;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                .then((_) => _load()),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.build), text: S.tabOpen, height: 64),
            Tab(icon: Icon(Icons.done_all), text: S.tabDone, height: 64),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: S.search,
                prefixIcon: const Icon(Icons.search, size: 28),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
                        }),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: BigButton(
                    icon: Icons.add_box,
                    label: S.newIntake,
                    onPressed: () => _open(const JobFormScreen(kind: 'intake')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BigButton(
                    icon: Icons.bolt,
                    label: S.quickJob,
                    color: kOrange,
                    onPressed: () => _open(const JobFormScreen(kind: 'quick')),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _jobs.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 64, color: kRed),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 16),
        BigButton(icon: Icons.refresh, label: S.retry, onPressed: _load),
      ]);
    }
    if (_jobs.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 100),
        Icon(Icons.inbox, size: 64, color: Colors.black38),
        SizedBox(height: 8),
        Center(child: Text(S.noJobs, style: TextStyle(fontSize: 22))),
      ]);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _jobs.length,
      itemBuilder: (_, i) => JobCard(
        job: _jobs[i],
        onTap: () => _open(JobDetailScreen(jobId: _jobs[i].id)),
      ),
    );
  }
}
