// lib/screens/stats/my_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';
import '../../utils/avatar_manager.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  List<GroupWithRankOutSchema> _groups = [];

  // Per-group data
  List<_GroupStatsData> _groupStats = [];

  // Global computed stats
  double _globalAvg = 0.0;
  double _globalMax = 0.0;
  int _totalSubmissions = 0;
  int _totalGradedSubmissions = 0;
  
  // Gamification stats
  int _currentStreak = 0;
  int _maxStreak = 0;
  int _totalFives = 0;

  // Chart data
  List<SubmissionOutSchema> _historicalSubmissions = [];

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
        _api.getMe(token),
        _api.getGroupsWithRank(token),
      ]);

      _user = results[0] as Map<String, dynamic>?;
      _groups = results[1] as List<GroupWithRankOutSchema>;

      // Fetch results for each group in parallel
      final groupFutures = _groups.map((group) async {
        final submissions = await _api.getStudentResults(token, group.id);
        return _GroupStatsData(group: group, submissions: submissions);
      });

      final groupStats = await Future.wait(groupFutures);

      // Compute global statistics
      final allSubmissions = groupStats.expand((g) => g.submissions).toList();
      final gradedSubmissions = allSubmissions
          .where((s) => s.gradeValue != null && s.gradeValue!.isNotEmpty)
          .toList();

      double globalAvg = 0.0;
      double globalMax = 0.0;

      if (allSubmissions.isNotEmpty) {
        globalAvg =
            allSubmissions.map((s) => s.percentage).reduce((a, b) => a + b) /
            allSubmissions.length;
        globalMax = allSubmissions
            .map((s) => s.percentage)
            .reduce((a, b) => a > b ? a : b);
      }
      
      // Calculate gamification stats
      int currentStreak = 0;
      int maxStreak = 0;
      int totalFives = 0;
      
      // Sort graded submissions chronologically (oldest to newest)
      final sortedGraded = List<SubmissionOutSchema>.from(gradedSubmissions);
      sortedGraded.sort((a, b) => (a.submittedAt ?? DateTime(0)).compareTo(b.submittedAt ?? DateTime(0)));
      
      for (var s in sortedGraded) {
        if (s.gradeValue == '5') {
          currentStreak++;
          totalFives++;
          if (currentStreak > maxStreak) {
            maxStreak = currentStreak;
          }
        } else {
          currentStreak = 0;
        }
      }

      setState(() {
        _groupStats = groupStats;
        _globalAvg = globalAvg;
        _globalMax = globalMax;
        _totalSubmissions = allSubmissions.length;
        _totalGradedSubmissions = gradedSubmissions.length;
        _currentStreak = currentStreak;
        _maxStreak = maxStreak;
        _totalFives = totalFives;
        _historicalSubmissions = sortedGraded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile stats: $e');
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
    return _isLoading ? _buildLoading() : _buildContent();
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('Statisztika'),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.withValues(alpha: 0.3),
              highlightColor: Colors.grey.withValues(alpha: 0.1),
              child: Container(
                height: 80 + (i * 20).toDouble(),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);

    if (_user == null) {
      return const Center(child: Text('Nem sikerült betölteni a profilt.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Statisztika'),
          const SizedBox(height: 16),
          // Profile card
          _buildProfileCard(theme),
          const SizedBox(height: 24),
          // Global summary
          _buildGlobalSummary(theme),
          const SizedBox(height: 24),
          // Progress Chart
          _buildProgressChart(theme),
          const SizedBox(height: 24),
          // Gamification
          _buildGamificationSection(theme),
          const SizedBox(height: 24),
          // Groups section
          if (_groupStats.isNotEmpty) ...[
            _buildGroupsSection(theme),
            const SizedBox(height: 24),
          ],
          // Recent results
          _buildRecentResults(theme),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.8),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadData,
            tooltip: 'Frissítés',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    final rawPfpUrl = _user!['pfp_url']?.toString();
    final pfpUrl = AvatarManager.getAvatarUrl(rawPfpUrl);
    final name = '${_user!['last_name'] ?? ''} ${_user!['first_name'] ?? ''}'
        .trim();
    final username = _user!['username']?.toString() ?? 'N/A';
    final dateJoined = _user!['date_joined'] != null
        ? DateFormat(
            'yyyy. MM. dd.',
          ).format(DateTime.parse(_user!['date_joined']))
        : null;

    final adminCount = _groups.where((g) => g.rank == 'ADMIN').length;
    final memberCount = _groups.where((g) => g.rank == 'MEMBER').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white24,
                child: pfpUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 36)
                    : ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: CachedNetworkImage(
                            imageUrl: pfpUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    if (dateJoined != null)
                      Text(
                        'Csatlakozás: $dateJoined',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (adminCount > 0)
                _buildBadge(
                  'Admin $adminCount csoportban',
                  Icons.admin_panel_settings,
                ),
              if (adminCount > 0 && memberCount > 0) const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGlobalSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Összesítés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.assignment_turned_in,
                  label: 'Beadások',
                  value: '$_totalSubmissions',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.grade,
                  label: 'Jegyezett',
                  value: '$_totalGradedSubmissions',
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.trending_up,
                  label: 'Átlag',
                  value: _totalSubmissions > 0
                      ? '${_globalAvg.toStringAsFixed(1)}%'
                      : '–',
                  color: _getPercentageColor(_globalAvg),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.emoji_events,
                  label: 'Legjobb',
                  value: _totalSubmissions > 0
                      ? '${_globalMax.toStringAsFixed(0)}%'
                      : '–',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  theme,
                  icon: Icons.groups,
                  label: 'Csoportok',
                  value: '${_groups.length}',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()), // spacer
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart(ThemeData theme) {
    if (_historicalSubmissions.isEmpty) return const SizedBox.shrink();

    // We only take the last 20 submissions to avoid a cramped chart
    final displayData = _historicalSubmissions.length > 20
        ? _historicalSubmissions.sublist(_historicalSubmissions.length - 20)
        : _historicalSubmissions;

    final List<FlSpot> spots = [];
    for (int i = 0; i < displayData.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayData[i].percentage));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eredmények alakulása',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 16, left: 0, top: 24, bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value > 100) return const SizedBox.shrink();
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              clipData: const FlClipData.none(),
              minX: 0,
              maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1,
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: theme.primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final grade = displayData[index].gradeValue;
                      Color dotColor = theme.primaryColor;
                      if (grade == '5') dotColor = Colors.green;
                      else if (grade == '4') dotColor = Colors.lightGreen;
                      else if (grade == '3') dotColor = Colors.amber.shade700;
                      else if (grade == '2') dotColor = Colors.orange;
                      else if (grade == '1') dotColor = Colors.red;

                      return FlDotCirclePainter(
                        radius: 5,
                        color: dotColor,
                        strokeWidth: 2,
                        strokeColor: theme.cardColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final sub = displayData[touchedSpot.spotIndex];
                      return LineTooltipItem(
                        '${sub.percentage.toStringAsFixed(0)}%\n${sub.gradeValue}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGamificationSection(ThemeData theme) {
    if (_totalSubmissions == 0) return const SizedBox.shrink();

    // Find the highest unlocked reward
    _RewardLevel? currentReward;
    for (var reward in _rewards) {
      if (_totalFives >= reward.requiredFives) {
        currentReward = reward;
        break; // Assuming the list is sorted in descending order
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Díjak és Eredmények',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              // Streak Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_currentStreak',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        'Jelenlegi Ötös Streak',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 40, color: theme.dividerColor),
                  Column(
                    children: [
                      Text(
                        '$_maxStreak',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        'Legjobb Streak',
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Total Fives row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Összes eddigi ötös:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    '$_totalFives db',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (currentReward != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentReward.icon,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${currentReward.requiredFives} Ötös Mérföldkő',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentReward.message,
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Case: Has not unlocked the first reward yet
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.disabledColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: theme.hintColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Első mérföldkő: ${_rewards.last.requiredFives} ötös',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Szerezz összesen ${_rewards.last.requiredFives} ötöst az első díjhoz!',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsSection(ThemeData theme) {
    // Only show groups that have submissions
    final groupsWithData = _groupStats
        .where((g) => g.submissions.isNotEmpty)
        .toList();

    if (groupsWithData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Csoportok teljesítménye',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        ...groupsWithData.map((gs) => _buildGroupCard(theme, gs)),
      ],
    );
  }

  Widget _buildGroupCard(ThemeData theme, _GroupStatsData gs) {
    final avg = gs.average;
    final gradeDistribution = gs.gradeDistribution;
    final groupColor = _parseColor(gs.group.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gs.group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${gs.submissions.length} beadás',
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getPercentageColor(avg).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${avg.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _getPercentageColor(avg),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avg / 100,
              color: groupColor,
              backgroundColor: groupColor.withValues(alpha: 0.1),
              minHeight: 6,
            ),
          ),
          // Grade distribution (if any graded submissions)
          if (gradeDistribution.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: gradeDistribution.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _getGradeColor(entry.key).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getGradeColor(entry.key).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}×',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getGradeColor(entry.key),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentResults(ThemeData theme) {
    final allSubmissions = _groupStats
        .expand(
          (g) => g.submissions.map(
            (s) => _SubmissionWithGroup(submission: s, groupName: g.group.name),
          ),
        )
        .toList();

    // Sort by date
    allSubmissions.sort(
      (a, b) => (b.submission.submittedAt ?? DateTime(0)).compareTo(
        a.submission.submittedAt ?? DateTime(0),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legutóbbi eredmények',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        if (allSubmissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined, size: 48, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    'Még nincs eredményed.',
                    style: TextStyle(color: theme.hintColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          ...allSubmissions.take(10).map((sw) => _buildResultRow(theme, sw)),
      ],
    );
  }

  Widget _buildResultRow(ThemeData theme, _SubmissionWithGroup sw) {
    final s = sw.submission;
    final date = s.submittedAt != null
        ? DateFormat('MM. dd. HH:mm').format(s.submittedAt!)
        : '–';
    final hasGrade = s.gradeValue != null && s.gradeValue!.isNotEmpty;
    final color = _getPercentageColor(s.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // Grade badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                hasGrade ? s.gradeValue! : '–',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: hasGrade ? 18 : 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.quizTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${sw.groupName} • $date',
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${s.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Color _getPercentageColor(double pct) {
    if (pct >= 85) return Colors.green;
    if (pct >= 70) return Colors.blue;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case '5':
        return Colors.green;
      case '4':
        return Colors.blue;
      case '3':
        return Colors.orange;
      case '2':
        return Colors.deepOrange;
      case '1':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return Colors.blue;
    try {
      String c = colorStr;
      if (c.startsWith('#')) c = c.substring(1);
      if (c.length == 6) c = 'FF$c';
      return Color(int.parse(c, radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

// --- Internal data classes ---

class _GroupStatsData {
  final GroupWithRankOutSchema group;
  final List<SubmissionOutSchema> submissions;

  _GroupStatsData({required this.group, required this.submissions});

  double get average {
    if (submissions.isEmpty) return 0.0;
    return submissions.map((s) => s.percentage).reduce((a, b) => a + b) /
        submissions.length;
  }

  Map<String, int> get gradeDistribution {
    final Map<String, int> dist = {};
    for (var s in submissions) {
      if (s.gradeValue != null && s.gradeValue!.isNotEmpty) {
        dist[s.gradeValue!] = (dist[s.gradeValue!] ?? 0) + 1;
      }
    }
    // Sort by grade descending (5, 4, 3, 2, 1)
    final sorted = Map.fromEntries(
      dist.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    return sorted;
  }
}

class _SubmissionWithGroup {
  final SubmissionOutSchema submission;
  final String groupName;

  _SubmissionWithGroup({required this.submission, required this.groupName});
}

class _RewardLevel {
  final int requiredFives;
  final IconData icon;
  final String message;
  const _RewardLevel(this.requiredFives, this.icon, this.message);
}

const List<_RewardLevel> _rewards = [
  _RewardLevel(200, Icons.emoji_events, "Abszolút Legenda!"),
  _RewardLevel(175, Icons.diamond, "Ragyogó elme!"),
  _RewardLevel(150, Icons.castle, "A tudás birodalma! Felépítetted a saját váradat."),
  _RewardLevel(123, Icons.speed, "1-2-3 és kész! Villámgyorsan gyűjtöd a sikereket."),
  _RewardLevel(100, Icons.military_tech, "Százas klub! Beléptél a legelitebb körbe."),
  _RewardLevel(85, Icons.psychology, "Mesterelme! A logika és a tudás nagykövete vagy."),
  _RewardLevel(67, Icons.auto_awesome, "Mágikus 67-es! A tudásod aranyat ér."),
  _RewardLevel(50, Icons.local_fire_department, "Lángol a tudásod! 50 siker már nem kis teljesítmény."),
  _RewardLevel(40, Icons.rocket_launch, "Űrsebességbe kapcsoltál! Senki sem érhet utol."),
  _RewardLevel(25, Icons.workspace_premium, "Negyed évszázadnyi ötös! Igazi profi vagy."),
  _RewardLevel(10, Icons.star, "Tízszeres bajnok! Ez már nem csak szerencse."),
  _RewardLevel(5, Icons.sentiment_very_satisfied, "Szép munka! Megtetted az első lépést a siker felé."),
];
