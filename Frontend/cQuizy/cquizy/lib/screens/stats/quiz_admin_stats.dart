// lib/screens/stats/quiz_admin_stats.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';

class QuizAdminStats extends StatefulWidget {
  final int quizId;
  final String quizTitle;

  const QuizAdminStats({super.key, required this.quizId, required this.quizTitle});

  @override
  State<QuizAdminStats> createState() => _QuizAdminStatsState();
}

class _QuizAdminStatsState extends State<QuizAdminStats> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  
  QuizStatsSchema? _stats;
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    try {
      final results = await Future.wait([
        _api.getQuizStatsModel(token, widget.quizId),
        _api.getQuizSubmissions(token, widget.quizId),
        _api.getQuizEvents(token, widget.quizId),
      ]);

      setState(() {
        _stats = results[0] as QuizStatsSchema?;
        _submissions = results[1] as List<Map<String, dynamic>>;
        _events = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading quiz admin stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.quizTitle)),
      body: _isLoading ? _buildLoading() : _buildContent(theme),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_stats != null) _buildStatsCard(theme),
        const SizedBox(height: 32),
        if (_submissions.isNotEmpty) ...[
          _buildScoreDistribution(theme),
          const SizedBox(height: 32),
          _buildResultsTable(theme),
          const SizedBox(height: 32),
        ],
        if (_events.isNotEmpty) ...[
          _buildEventLog(theme),
          const SizedBox(height: 32),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    return Row(
      children: [
        _buildMiniCard('Átlag', '${_stats!.averageScore.toStringAsFixed(1)}%', theme.primaryColor),
        _buildMiniCard('Max', '${_stats!.maxScore.toStringAsFixed(0)}%', Colors.green),
        _buildMiniCard('Min', '${_stats!.minScore.toStringAsFixed(0)}%', Colors.red),
        _buildMiniCard('Beadás', '${_stats!.submissionCount}', Colors.blue),
      ],
    );
  }

  Widget _buildMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDistribution(ThemeData theme) {
    // Histogram buckets: 0-10, 10-20, ..., 90-100
    final buckets = List.filled(10, 0);
    for (var sub in _submissions) {
      final pct = (sub['percentage'] as num?)?.toDouble() ?? 0.0;
      final bucketIdx = (pct / 10).floor().clamp(0, 9);
      buckets[bucketIdx]++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Eredmények eloszlása', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 3.0,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceEvenly,
              maxY: buckets.map((e) => e.toDouble()).reduce((a, b) => a > b ? a : b) + 1,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${(v * 10).toInt()}%', style: const TextStyle(fontSize: 8))),
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(buckets.length, (index) => BarChartGroupData(
                x: index,
                barRods: [BarChartRodData(toY: buckets[index].toDouble(), color: theme.primaryColor, width: 20, borderRadius: BorderRadius.circular(4))],
              )),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsTable(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Diákok eredményei', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Diák')),
              DataColumn(label: Text('%')),
              DataColumn(label: Text('Jegy')),
              DataColumn(label: Text('Időpont')),
            ],
            rows: _submissions.map((sub) => DataRow(cells: [
              DataCell(Text(sub['student_name'] ?? 'Ismeretlen')),
              DataCell(Text('${((sub['percentage'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}%')),
              DataCell(Text(sub['grade']?.toString() ?? '-')),
              DataCell(Text(sub['submitted_at'] != null ? DateFormat('HH:mm').format(DateTime.parse(sub['submitted_at'])) : '-')),
            ])).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEventLog(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Eseménynapló', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._events.map((e) {
          final isCheat = e['type'] == 'STUDENT_CHEAT';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(isCheat ? Icons.warning_amber_rounded : Icons.info_outline, color: isCheat ? Colors.red : Colors.grey),
              title: Text(e['student_name'] ?? 'Rendszer'),
              subtitle: Text('${e['type']} - ${e['status']}'),
              trailing: Text(DateFormat('HH:mm:ss').format(DateTime.parse(e['created_at']))),
            ),
          );
        }),
      ],
    );
  }
}
