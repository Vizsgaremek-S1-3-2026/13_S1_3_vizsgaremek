// lib/screens/stats/student_group_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';

class StudentGroupDashboard extends StatefulWidget {
  final int groupId;
  final String groupName;

  const StudentGroupDashboard({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<StudentGroupDashboard> createState() => _StudentGroupDashboardState();
}

class _StudentGroupDashboardState extends State<StudentGroupDashboard> {
  final ApiService _api = ApiService();
  bool _isLoading = true;

  List<SubmissionOutSchema> _results = [];
  List<Map<String, dynamic>> _comparisonData = [];
  List<Map<String, dynamic>> _upcomingQuizzes = [];

  AdminGroupOverviewSchema? _groupOverview;

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
        _api.getStudentResults(token, widget.groupId),
        _api.getGroupQuizzes(token, widget.groupId),
        _api
            .getGroupStatsOverview(token, widget.groupId)
            .catchError((_) => null), // Silent fail if no permission
      ]);

      final submissions = results[0] as List<SubmissionOutSchema>;
      final allQuizzes = results[1] as List<dynamic>;
      _groupOverview = results[2] as AdminGroupOverviewSchema?;

      // Filter upcoming
      final now = DateTime.now();
      final upcoming = allQuizzes.where((q) {
        final start = DateTime.tryParse(q['date_start'] ?? '');
        return start != null && start.isAfter(now);
      }).toList();

      // Comparison data
      final List<Map<String, dynamic>> comparison = [];
      final lastResults = submissions.take(5).toList();
      for (var r in lastResults) {
        final stats = await _api.getQuizStatsModel(token, r.quizId ?? 0);
        comparison.add({
          'quiz': r.quizTitle,
          'own': r.percentage,
          'avg': stats?.averageScore ?? 0.0,
        });
      }

      setState(() {
        _results = submissions;
        _comparisonData = comparison;
        _upcomingQuizzes = upcoming.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading student dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
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
        _buildProgressCard(theme),
        const SizedBox(height: 32),
        if (_results.isNotEmpty) ...[
          _buildResultsTimeline(theme),
          const SizedBox(height: 32),
        ],
        if (_comparisonData.isNotEmpty) ...[
          _buildComparisonSection(theme),
          const SizedBox(height: 32),
        ],
        if (_upcomingQuizzes.isNotEmpty) ...[
          _buildUpcomingQuizzes(theme),
          const SizedBox(height: 32),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildProgressCard(ThemeData theme) {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
        ),
        child: const Text(
          'Még nincsenek eredményeid ebben a csoportban.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final avg =
        _results.map((r) => r.percentage).reduce((a, b) => a + b) /
        _results.length;
    final best = _results
        .map((r) => r.percentage)
        .reduce((a, b) => a > b ? a : b);
    final classAvg = _groupOverview?.averagePercentage ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saját Átlag', style: TextStyle(fontSize: 14)),
                  Text(
                    '${avg.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              if (classAvg > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Osztályátlag', style: TextStyle(fontSize: 12)),
                    Text(
                      '${classAvg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSubStat(
                  'Legjobb',
                  '${best.toStringAsFixed(0)}%',
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  'Kvízek',
                  '${_results.length}',
                  Colors.blue,
                ),
              ),
              if (classAvg > 0)
                Expanded(
                  child: _buildSubStat(
                    'Különbség',
                    '${(avg - classAvg).toStringAsFixed(1)}%',
                    (avg >= classAvg ? Colors.green : Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultsTimeline(ThemeData theme) {
    final sortedByDate = List<SubmissionOutSchema>.from(_results);
    sortedByDate.sort(
      (a, b) => (a.submittedAt ?? DateTime(0)).compareTo(
        b.submittedAt ?? DateTime(0),
      ),
    );

    final spots = List.generate(
      sortedByDate.length,
      (i) => FlSpot(i.toDouble(), sortedByDate[i].percentage),
    );
    final classAvg = _groupOverview?.averagePercentage ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eredmények alakulása',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 3.0,
          child: LineChart(
            LineChartData(
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (classAvg > 0)
                    HorizontalLine(
                      y: classAvg,
                      color: Colors.grey.withValues(alpha: 0.3),
                      strokeWidth: 2,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        labelResolver: (v) => 'Osztályátlag',
                      ),
                    ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 4,
                  color: theme.primaryColor,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.primaryColor.withValues(alpha: 0.1),
                  ),
                ),
              ],
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Összehasonlítás az Osztállyal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._comparisonData.map(
          (data) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['quiz'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildCompareBar(
                        'Én',
                        data['own'],
                        theme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompareBar(
                        'Átlag',
                        data['avg'],
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompareBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 10)),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 100,
            color: color,
            backgroundColor: color.withValues(alpha: 0.1),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingQuizzes(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Közelgő Kvízek',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._upcomingQuizzes.map(
          (q) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                q['project_name'] ?? 'Kvíz',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Kezdés: ${DateFormat('MM. dd. HH:mm').format(DateTime.parse(q['date_start']))}',
              ),
              trailing: const Icon(Icons.timer_outlined, color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }
}
