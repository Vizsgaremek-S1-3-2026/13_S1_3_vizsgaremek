// lib/screens/stats/live_quiz_monitor_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';

class LiveQuizMonitorScreen extends StatefulWidget {
  final int quizId;
  final String quizTitle;

  const LiveQuizMonitorScreen({super.key, required this.quizId, required this.quizTitle});

  @override
  State<LiveQuizMonitorScreen> createState() => _LiveQuizMonitorScreenState();
}

class _LiveQuizMonitorScreenState extends State<LiveQuizMonitorScreen> {
  final ApiService _api = ApiService();
  Timer? _timer;
  bool _isLoading = true;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    final data = await _api.getQuizStatus(token, widget.quizId);
    if (mounted) {
      setState(() {
        _status = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quizTitle} - Monitor'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchStatus),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_status == null) return const Center(child: Text('Nem sikerült betölteni az adatokat.'));

    final writing = (_status!['writing'] as List?)?.length ?? 0;
    final finished = (_status!['finished'] as List?)?.length ?? 0;
    final locked = (_status!['locked'] as List?)?.length ?? 0;
    final suspended = (_status!['suspended'] as List?)?.length ?? 0;
    final idle = (_status!['idle'] as List?)?.length ?? 0;
    final total = writing + finished + locked + suspended + idle;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStatusChart(writing, finished, locked, suspended, idle, total, theme),
        const SizedBox(height: 32),
        _buildStatusSection('Írják (${writing})', _status!['writing'], Colors.blue, theme),
        _buildStatusSection('Befejezték (${finished})', _status!['finished'], Colors.green, theme),
        _buildStatusSection('Zárolva (${locked})', _status!['locked'], Colors.red, theme, hasUnlock: true),
        _buildStatusSection('Kizárva (${suspended})', _status!['suspended'], Colors.black87, theme),
        _buildStatusSection('Még nem kezdték (${idle})', _status!['idle'], Colors.grey, theme),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatusChart(int writing, int finished, int locked, int suspended, int idle, int total, ThemeData theme) {
    return AspectRatio(
      aspectRatio: 2.2,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sections: [
                if (writing > 0) PieChartSectionData(value: writing.toDouble(), color: Colors.blue, title: 'Ír', radius: 40, showTitle: false),
                if (finished > 0) PieChartSectionData(value: finished.toDouble(), color: Colors.green, title: 'Kész', radius: 40, showTitle: false),
                if (locked > 0) PieChartSectionData(value: locked.toDouble(), color: Colors.red, title: 'Lock', radius: 40, showTitle: false),
                if (suspended > 0) PieChartSectionData(value: suspended.toDouble(), color: Colors.black87, title: 'Susp', radius: 40, showTitle: false),
                if (idle > 0) PieChartSectionData(value: idle.toDouble(), color: Colors.grey, title: 'Idle', radius: 40, showTitle: false),
              ],
              sectionsSpace: 4,
              centerSpaceRadius: 60,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$total', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('Diák összesen', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(String title, List? students, Color color, ThemeData theme, {bool hasUnlock = false}) {
    if (students == null || students.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ),
        ...students.map((s) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Text(s['username']?[0]?.toUpperCase() ?? 'U', style: TextStyle(color: color))),
            title: Text(s['username'] ?? 'Ismeretlen'),
            trailing: hasUnlock ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _unlockStudent(s['id']),
                  child: const Text('Feloldás', style: TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () => _closeStudent(s['id']),
                  child: const Text('Bezárás', style: TextStyle(color: Colors.red)),
                ),
              ],
            ) : null,
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _unlockStudent(int studentId) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    final success = await _api.unlockStudent(token, widget.quizId, studentId);
    if (success) _fetchStatus();
  }

  Future<void> _closeStudent(int studentId) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    final res = await _api.closeStudentDetailed(token, widget.quizId, studentId);
    if (res['success']) _fetchStatus();
  }
}
