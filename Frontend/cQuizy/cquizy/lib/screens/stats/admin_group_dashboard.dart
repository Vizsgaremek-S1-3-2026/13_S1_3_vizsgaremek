// lib/screens/stats/admin_group_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';

class AdminGroupDashboard extends StatefulWidget {
  final int groupId;
  final String groupName;

  const AdminGroupDashboard({super.key, required this.groupId, required this.groupName});

  @override
  State<AdminGroupDashboard> createState() => _AdminGroupDashboardState();
}

class _AdminGroupDashboardState extends State<AdminGroupDashboard> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  
  AdminGroupOverviewSchema? _overview;
  List<AdminStudentStatSchema> _studentStats = [];
  List<AdminQuizStatSchema> _quizStats = [];
  List<MemberOutSchema> _members = [];
  List<GradePercentageSchema> _gradingScale = [];

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
        _api.getGroupStatsOverview(token, widget.groupId),
        _api.getGroupStudentStats(token, widget.groupId),
        _api.getGroupQuizStats(token, widget.groupId),
        _api.getGroupMembers(token, widget.groupId),
        _api.getGroupGradingScale(token, widget.groupId),
      ]);

      setState(() {
        _overview = results[0] as AdminGroupOverviewSchema?;
        _studentStats = results[1] as List<AdminStudentStatSchema>;
        _quizStats = results[2] as List<AdminQuizStatSchema>;
        _members = (results[3] as List).map((e) => MemberOutSchema.fromJson(e)).toList();
        _gradingScale = results[4] as List<GradePercentageSchema>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba az adatok betöltésekor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} - Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading ? _buildLoading(theme) : _buildContent(theme),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.3),
          highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Row(
            children: List.generate(4, (index) => Expanded(
              child: Container(height: 80, margin: const EdgeInsets.symmetric(horizontal: 4), 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ),
        ),
        const SizedBox(height: 32),
        AspectRatio(aspectRatio: 1.5, child: Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.3), highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Container(color: Colors.white),
        )),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_overview != null) _buildOverviewRow(theme),
        const SizedBox(height: 32),
        if (_studentStats.isNotEmpty) ...[
          _buildStudentLeaderboard(theme),
          const SizedBox(height: 32),
        ],
        if (_quizStats.isNotEmpty) ...[
          _buildQuizDifficultyChart(theme),
          const SizedBox(height: 32),
        ],
        if (_members.isNotEmpty) ...[
          _buildMemberGrowthChart(theme),
          const SizedBox(height: 32),
        ],
        if (_gradingScale.isNotEmpty) ...[
          _buildGradingScale(theme),
          const SizedBox(height: 32),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildOverviewRow(ThemeData theme) {
    return Row(
      children: [
        _buildStatCard(theme, 'Átlag', '${_overview!.averagePercentage.toStringAsFixed(1)}%', Icons.bar_chart, Colors.blue),
        _buildStatCard(theme, 'Jegy', _overview!.averageGradeLabel, Icons.emoji_events, Colors.orange),
        _buildStatCard(theme, 'Diákok', '${_overview!.totalStudents}', Icons.people, Colors.green),
        _buildStatCard(theme, 'Kvízek', '${_overview!.totalQuizzes}', Icons.assignment, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: TextStyle(color: theme.hintColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentLeaderboard(ThemeData theme) {
    // Top 10 students
    final sortedStats = List<AdminStudentStatSchema>.from(_studentStats);
    sortedStats.sort((a, b) => b.averagePercentage.compareTo(a.averagePercentage));
    final displayData = sortedStats.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Diákok Ranglistája (Top 10)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 2.5,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= displayData.length) return const SizedBox.shrink();
                    final name = displayData[index].name;
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Transform.rotate(angle: -0.6, child: Text(name.length > 6 ? '${name.substring(0, 5)}..' : name, style: const TextStyle(fontSize: 9))),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${v.toInt()}%', style: const TextStyle(fontSize: 9))))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(displayData.length, (index) {
                final pct = displayData[index].averagePercentage;
                final color = pct >= 85 ? Colors.green : (pct >= 70 ? Colors.blue : (pct >= 50 ? Colors.orange : Colors.red));
                return BarChartGroupData(
                  x: index,
                  barRods: [BarChartRodData(toY: pct, color: color, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizDifficultyChart(ThemeData theme) {
    if (_quizStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kvízek Nehézsége & Kitöltöttség', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 3.0,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: List.generate(_quizStats.length, (i) {
                final q = _quizStats[i];
                return ScatterSpot(
                  i.toDouble(),
                  q.averagePercentage,
                );
              }),
              minX: -0.5,
              maxX: _quizStats.length.toDouble() - 0.5,
              minY: 0,
              maxY: 110,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text('${v.toInt()}%', style: const TextStyle(fontSize: 10))))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('Tengely: Kvízek sorrendben | Magasság: Átlagos %', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }

  Widget _buildMemberGrowthChart(ThemeData theme) {
    final sortedMembers = List<MemberOutSchema>.from(_members);
    sortedMembers.sort((a, b) => (a.dateJoined ?? DateTime(2020)).compareTo(b.dateJoined ?? DateTime(2020)));
    
    final List<FlSpot> spots = [];
    int count = 0;
    for (int i = 0; i < sortedMembers.length; i++) {
      count++;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tagság Növekedése', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 3.0,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: theme.primaryColor,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: theme.primaryColor.withValues(alpha: 0.1)),
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

  Widget _buildGradingScale(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Értékelési Határok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._gradingScale.map((g) => Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${g.minPercentage.toStringAsFixed(0)}% – ${g.maxPercentage.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: g.maxPercentage / 100,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                  color: _getGradeColorScale(g.name),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _getGradeColorScale(String name) {
    if (name.contains('5') || name.toLowerCase().contains('jeles')) return Colors.green;
    if (name.contains('4') || name.toLowerCase().contains('jó')) return Colors.lightGreen;
    if (name.contains('3') || name.toLowerCase().contains('közepes')) return Colors.orange;
    if (name.contains('2') || name.toLowerCase().contains('elégséges')) return Colors.deepOrange;
    return Colors.red;
  }
}
