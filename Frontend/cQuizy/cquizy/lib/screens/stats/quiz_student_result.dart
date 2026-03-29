// lib/screens/stats/quiz_student_result.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';

class QuizStudentResult extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  final int? submissionId;

  const QuizStudentResult({super.key, required this.quizId, required this.quizTitle, this.submissionId});

  @override
  State<QuizStudentResult> createState() => _QuizStudentResultState();
}

class _QuizStudentResultState extends State<QuizStudentResult> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  
  Map<String, dynamic>? _submissionDetail;
  QuizStatsSchema? _quizStats;

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
      int? subId = widget.submissionId;
      final results = await Future.wait([
        if (subId != null) _api.getSubmissionDetails(token, subId) else Future.value(null),
        _api.getQuizStatsModel(token, widget.quizId),
      ]);

      setState(() {
        _submissionDetail = results[0] as Map<String, dynamic>?;
        _quizStats = results[1] as QuizStatsSchema?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading student quiz result: $e');
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
        if (_submissionDetail != null) _buildScoreCard(theme),
        const SizedBox(height: 32),
        if (_quizStats != null && _submissionDetail != null) ...[
          _buildComparisonScale(theme),
          const SizedBox(height: 32),
        ],
        if (_submissionDetail != null && _submissionDetail!['answers'] != null) ...[
          const Text('Kérdések értékelése', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...(_submissionDetail!['answers'] as List).map((ans) => _buildQuestionTile(theme, ans)),
          const SizedBox(height: 32),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildScoreCard(ThemeData theme) {
    final pct = (_submissionDetail!['percentage'] as num?)?.toDouble() ?? 0.0;
    final color = _getGradeColorResult(pct);
    final grade = _submissionDetail!['grade']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                   PieChart(
                     PieChartData(
                       sections: [
                         PieChartSectionData(value: pct, color: color, radius: 10, showTitle: false),
                         PieChartSectionData(value: 100 - pct, color: color.withValues(alpha: 0.1), radius: 8, showTitle: false),
                       ],
                       startDegreeOffset: 270,
                       sectionsSpace: 0,
                       centerSpaceRadius: 35,
                     ),
                   ),
                   Center(
                     child: Text(
                       '${pct.toStringAsFixed(0)}%',
                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                     ),
                   ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Elért eredmény', style: TextStyle(color: theme.hintColor, fontSize: 12)),
                Text('${_submissionDetail!['score']} / ${_submissionDetail!['max_score']} pont', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: Text('Jegy: $grade', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonScale(ThemeData theme) {
    final own = (_submissionDetail!['percentage'] as num?)?.toDouble() ?? 0.0;
    final avg = _quizStats!.averageScore;
    final best = _quizStats!.maxScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Helyezés az osztályban', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 48), // Space for top labels
        SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 25,
                left: 0, right: 0,
                child: Container(height: 6, decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3))),
              ),
              _buildMarker(avg, Colors.grey, 'Átlag', true),
              _buildMarker(best, Colors.green, 'Legjobb', true),
              _buildMarker(own, theme.primaryColor, 'Én', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarker(double pct, Color color, String label, bool isTop) {
    return Positioned(
      left: (pct / 100 * (MediaQuery.of(context).size.width - 40)) - 30, // 40 is padding
      bottom: isTop ? 28 : 0,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            if (isTop) ...[
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: color)),
              Container(width: 2, height: 6, color: color),
            ] else ...[
              Container(width: 2, height: 6, color: color),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTile(ThemeData theme, Map<String, dynamic> ans) {
    final isCorrect = (ans['points_awarded'] as num? ?? 0) >= (ans['max_points'] as num? ?? 1);
    final partial = (ans['points_awarded'] as num? ?? 0) > 0 && !isCorrect;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(
          isCorrect ? Icons.check_circle_rounded : (partial ? Icons.adjust_rounded : Icons.cancel_rounded),
          color: isCorrect ? Colors.green : (partial ? Colors.orange : Colors.red),
        ),
        title: Text(ans['block_question'] ?? 'Kérdés', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Szerzett pont: ${ans['points_awarded']} / ${ans['max_points']}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saját válaszed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(ans['student_answer'] ?? '(Üres)', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColorResult(double pct) {
    if (pct >= 85) return Colors.green;
    if (pct >= 70) return Colors.blue;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }
}
