import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Aggregated data
  int _totalTests = 0;
  int _completedTests = 0;
  double _averagePercentage = 0.0;
  double _bestPercentage = 0.0;
  String _bestTestName = '';
  double _worstPercentage = 100.0;
  String _worstTestName = '';
  int _totalScore = 0;
  int _totalMaxScore = 0;

  // Per-group data
  List<_GroupStats> _groupStats = [];

  // Recent results
  List<_TestResult> _allResults = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fetchStatistics();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatistics() async {
    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final api = ApiService();
    try {
      final groups = await api.getUserGroups(token);

      final List<_GroupStats> groupStatsList = [];
      final List<_TestResult> allResults = [];
      int totalTests = 0;
      int completedTests = 0;
      double bestPct = 0;
      String bestName = '';
      double worstPct = 100;
      String worstName = '';
      double sumPct = 0;
      int totalScore = 0;
      int totalMaxScore = 0;

      for (var group in groups) {
        final groupId = group['id'] as int;
        final groupName = (group['name'] ?? 'Ismeretlen csoport').toString();
        final groupColor = group['color']?.toString();
        final isAdmin = group['rank'] == 'ADMIN';

        final quizzes = await api.getGroupQuizzes(token, groupId);
        final results = await api.getUserResults(token, groupId);

        // Build quiz map
        final quizMap = <int, Map<String, dynamic>>{};
        for (var q in quizzes) {
          quizMap[q['id'] as int] = q;
        }

        final now = DateTime.now();
        final pastQuizzes = quizzes.where((q) {
          final end = DateTime.tryParse(q['date_end'] ?? '');
          return end != null && end.isBefore(now);
        }).toList();

        totalTests += pastQuizzes.length;

        // Process results and group per-quiz
        final Map<int, List<_TestResult>> quizResultsMap = {};
        final List<_TestResult> groupResults = [];

        for (var result in results) {
          final quizId = result['quiz_id'] as int?;
          final score = (result['score'] as num?)?.toDouble() ?? 0;
          final maxScore = (result['max_score'] as num?)?.toDouble() ?? 0;
          final grade = result['grade'] as int?;
          final submittedAt = result['submitted_at']?.toString();

          final quiz = quizId != null ? quizMap[quizId] : null;
          final title =
              quiz?['project_name']?.toString() ??
              quiz?['title']?.toString() ??
              result['quiz_title']?.toString() ??
              result['title']?.toString() ??
              'Teszt #$quizId';

          final pct = maxScore > 0 ? (score / maxScore * 100) : 0.0;

          final testResult = _TestResult(
            quizId: quizId ?? 0,
            title: title,
            groupName: groupName,
            score: score,
            maxScore: maxScore,
            percentage: pct,
            grade: grade,
            date: submittedAt != null ? DateTime.tryParse(submittedAt) : null,
            dateStart: quiz != null
                ? DateTime.tryParse(quiz['date_start'] ?? '')
                : null,
            dateEnd: quiz != null
                ? DateTime.tryParse(quiz['date_end'] ?? '')
                : null,
            questionCount: quiz?['question_count'] as int?,
            timeLimitMinutes: quiz?['time_limit'] as int?,
          );

          groupResults.add(testResult);
          allResults.add(testResult);

          if (quizId != null) {
            quizResultsMap.putIfAbsent(quizId, () => []).add(testResult);
          }

          completedTests++;
          sumPct += pct;
          totalScore += score.round();
          totalMaxScore += maxScore.round();

          if (pct > bestPct) {
            bestPct = pct;
            bestName = title;
          }
          if (pct < worstPct) {
            worstPct = pct;
            worstName = title;
          }
        }

        // Build per-quiz stats
        final List<_QuizDetailStats> quizDetailStats = [];
        for (var entry in quizResultsMap.entries) {
          final qResults = entry.value;
          final qTitle = qResults.first.title;
          final qAvg = qResults.isNotEmpty
              ? qResults.map((r) => r.percentage).reduce((a, b) => a + b) /
                    qResults.length
              : 0.0;
          final qBest = qResults.isNotEmpty
              ? qResults
                    .map((r) => r.percentage)
                    .reduce((a, b) => a > b ? a : b)
              : 0.0;
          final qTotalScore = qResults
              .map((r) => r.score)
              .reduce((a, b) => a + b);
          final qTotalMax = qResults
              .map((r) => r.maxScore)
              .reduce((a, b) => a + b);

          quizDetailStats.add(
            _QuizDetailStats(
              quizId: entry.key,
              title: qTitle,
              attempts: qResults.length,
              averagePercentage: qAvg,
              bestPercentage: qBest,
              totalScore: qTotalScore,
              totalMaxScore: qTotalMax,
              lastGrade: qResults.last.grade,
              results: qResults,
            ),
          );
        }

        // Also add quizzes that have no results (missed) — only for non-admin groups
        if (!isAdmin) {
          for (var pq in pastQuizzes) {
            final qid = pq['id'] as int;
            if (!quizResultsMap.containsKey(qid)) {
              quizDetailStats.add(
                _QuizDetailStats(
                  quizId: qid,
                  title:
                      pq['project_name']?.toString() ??
                      pq['title']?.toString() ??
                      'Teszt #$qid',
                  attempts: 0,
                  averagePercentage: 0,
                  bestPercentage: 0,
                  totalScore: 0,
                  totalMaxScore: 0,
                  lastGrade: null,
                  results: [],
                ),
              );
            }
          }
        }

        // Sort: completed first, then by date
        quizDetailStats.sort((a, b) {
          if (a.attempts > 0 && b.attempts == 0) return -1;
          if (a.attempts == 0 && b.attempts > 0) return 1;
          return b.quizId.compareTo(a.quizId);
        });

        // Group average
        final groupAvg = groupResults.isNotEmpty
            ? groupResults.map((r) => r.percentage).reduce((a, b) => a + b) /
                  groupResults.length
            : 0.0;
        final groupBest = groupResults.isNotEmpty
            ? groupResults
                  .map((r) => r.percentage)
                  .reduce((a, b) => a > b ? a : b)
            : 0.0;

        groupStatsList.add(
          _GroupStats(
            groupId: groupId,
            groupName: groupName,
            groupColor: groupColor,
            totalQuizzes: pastQuizzes.length,
            completedQuizzes: groupResults.length,
            averagePercentage: groupAvg,
            bestPercentage: groupBest,
            results: groupResults,
            quizDetails: quizDetailStats,
          ),
        );
      }

      // Sort recent by date
      allResults.sort((a, b) {
        final da = a.date ?? DateTime(2000);
        final db = b.date ?? DateTime(2000);
        return db.compareTo(da);
      });

      // Sort groups by avg descending
      groupStatsList.sort(
        (a, b) => b.averagePercentage.compareTo(a.averagePercentage),
      );

      setState(() {
        _totalTests = totalTests;
        _completedTests = completedTests;
        _averagePercentage = completedTests > 0 ? sumPct / completedTests : 0;
        _bestPercentage = bestPct;
        _bestTestName = bestName;
        _worstPercentage = completedTests > 0 ? worstPct : 0;
        _worstTestName = worstName;
        _totalScore = totalScore;
        _totalMaxScore = totalMaxScore;
        _groupStats = groupStatsList;
        _allResults = allResults;
        _isLoading = false;
      });

      _animController.forward();
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a statisztikák betöltésekor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: theme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Statisztika',
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: theme.hintColor),
                  tooltip: 'Frissítés',
                  onPressed: _fetchStatistics,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(height: 1, color: theme.dividerColor),
        ),
        const SizedBox(height: 12),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _completedTests == 0 && _totalTests == 0
              ? _buildEmptyState(theme)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _fetchStatistics,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        const SizedBox(height: 8),
                        _buildOverviewSection(theme),
                        const SizedBox(height: 24),
                        _buildPerformanceBar(theme),
                        const SizedBox(height: 24),
                        _buildGroupsSection(theme),
                        const SizedBox(height: 24),
                        _buildRecentResultsSection(theme),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: theme.hintColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Még nincsenek eredményeid',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Töltsd ki az első teszted, és itt megjelennek a statisztikáid!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // OVERVIEW SECTION – Summary Cards
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildOverviewSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Összesítés', Icons.dashboard_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final cardWidth = isMobile
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 36) / 4;

            final cards = [
              _buildSummaryCard(
                theme,
                icon: Icons.assignment_turned_in_outlined,
                label: 'Kitöltött teszt',
                value: '$_completedTests / $_totalTests',
                detail: _totalTests > 0
                    ? '${(_completedTests / _totalTests * 100).toStringAsFixed(0)}% teljesítve'
                    : null,
                color: Colors.blue,
              ),
              _buildSummaryCard(
                theme,
                icon: Icons.percent_rounded,
                label: 'Átlagos eredmény',
                value: '${_averagePercentage.toStringAsFixed(1)}%',
                detail: '$_totalScore / $_totalMaxScore pont összesen',
                color: _getGradeColor(_averagePercentage),
              ),
              _buildSummaryCard(
                theme,
                icon: Icons.emoji_events_outlined,
                label: 'Legjobb eredmény',
                value: '${_bestPercentage.toStringAsFixed(1)}%',
                detail: _bestTestName,
                color: Colors.amber.shade700,
              ),
              _buildSummaryCard(
                theme,
                icon: Icons.trending_down_rounded,
                label: 'Leggyengébb',
                value: _completedTests > 0
                    ? '${_worstPercentage.toStringAsFixed(1)}%'
                    : '–',
                detail: _worstTestName,
                color: Colors.red.shade400,
              ),
            ];

            if (isMobile) {
              return Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: cardWidth, child: cards[0]),
                      const SizedBox(width: 12),
                      SizedBox(width: cardWidth, child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: cardWidth, child: cards[2]),
                      const SizedBox(width: 12),
                      SizedBox(width: cardWidth, child: cards[3]),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children:
                  cards
                      .expand(
                        (c) => [Expanded(child: c), const SizedBox(width: 12)],
                      )
                      .toList()
                    ..removeLast(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PERFORMANCE BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPerformanceBar(ThemeData theme) {
    if (_completedTests == 0) return const SizedBox.shrink();

    // Grade distribution
    int grade5 = 0, grade4 = 0, grade3 = 0, grade2 = 0, grade1 = 0;
    for (var r in _allResults) {
      final g = r.grade;
      if (g == null) continue;
      if (g == 5) {
        grade5++;
      } else if (g == 4) {
        grade4++;
      } else if (g == 3) {
        grade3++;
      } else if (g == 2) {
        grade2++;
      } else {
        grade1++;
      }
    }
    final hasGrades = grade5 + grade4 + grade3 + grade2 + grade1 > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          'Teljesítmény eloszlás',
          Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              if (hasGrades) ...[
                // Grade bars
                _buildGradeBar(
                  theme,
                  'Jeles (5)',
                  grade5,
                  _completedTests,
                  Colors.green,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  'Jó (4)',
                  grade4,
                  _completedTests,
                  Colors.lightGreen,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  'Közepes (3)',
                  grade3,
                  _completedTests,
                  Colors.orange,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  'Elégséges (2)',
                  grade2,
                  _completedTests,
                  Colors.deepOrange,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  'Elégtelen (1)',
                  grade1,
                  _completedTests,
                  Colors.red,
                ),
              ] else ...[
                // Percentage distribution
                _buildGradeBar(
                  theme,
                  '80-100%',
                  _allResults.where((r) => r.percentage >= 80).length,
                  _completedTests,
                  Colors.green,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  '60-79%',
                  _allResults
                      .where((r) => r.percentage >= 60 && r.percentage < 80)
                      .length,
                  _completedTests,
                  Colors.lightGreen,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  '40-59%',
                  _allResults
                      .where((r) => r.percentage >= 40 && r.percentage < 60)
                      .length,
                  _completedTests,
                  Colors.orange,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  '20-39%',
                  _allResults
                      .where((r) => r.percentage >= 20 && r.percentage < 40)
                      .length,
                  _completedTests,
                  Colors.deepOrange,
                ),
                const SizedBox(height: 10),
                _buildGradeBar(
                  theme,
                  '0-19%',
                  _allResults.where((r) => r.percentage < 20).length,
                  _completedTests,
                  Colors.red,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradeBar(
    ThemeData theme,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8),
                  child: pct > 0.15
                      ? Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GROUPS SECTION – Per-group with per-test details
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGroupsSection(ThemeData theme) {
    if (_groupStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          'Csoportok részletezése',
          Icons.groups_rounded,
        ),
        const SizedBox(height: 12),
        ..._groupStats.map((g) => _buildGroupExpansion(theme, g)),
      ],
    );
  }

  Widget _buildGroupExpansion(ThemeData theme, _GroupStats group) {
    final avgColor = _getGradeColor(group.averagePercentage);
    final missedCount = group.totalQuizzes - group.completedQuizzes;

    // Parse group color
    Color groupAccent = theme.primaryColor;
    if (group.groupColor != null) {
      try {
        final hex = group.groupColor!.replaceFirst('#', '');
        groupAccent = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  groupAccent.withValues(alpha: 0.2),
                  groupAccent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.group_outlined, color: groupAccent, size: 24),
          ),
          title: Text(
            group.groupName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildMiniBadge(
                  '${group.completedQuizzes}/${group.totalQuizzes} teszt',
                  theme.hintColor,
                  theme,
                ),
                if (group.completedQuizzes > 0)
                  _buildMiniBadge(
                    'Átlag: ${group.averagePercentage.toStringAsFixed(1)}%',
                    avgColor,
                    theme,
                  ),
                if (group.completedQuizzes > 0)
                  _buildMiniBadge(
                    'Legjobb: ${group.bestPercentage.toStringAsFixed(1)}%',
                    Colors.amber.shade700,
                    theme,
                  ),
                if (missedCount > 0)
                  _buildMiniBadge(
                    '$missedCount hiányzó',
                    Colors.red.shade400,
                    theme,
                  ),
              ],
            ),
          ),
          children: [
            if (group.quizDetails.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nincsenek tesztek ebben a csoportban.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ...group.quizDetails.map((q) => _buildQuizDetailCard(theme, q)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Per-Quiz Detail Card ──────────────────────────────────────────

  Widget _buildQuizDetailCard(ThemeData theme, _QuizDetailStats quiz) {
    final isMissed = quiz.attempts == 0;
    final color = isMissed ? Colors.grey : _getGradeColor(quiz.bestPercentage);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMissed
              ? Colors.red.withValues(alpha: 0.2)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isMissed
                      ? Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        )
                      : Text(
                          '${quiz.bestPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                      quiz.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isMissed)
                      Text(
                        'Nem kitöltött',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isMissed && quiz.lastGrade != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Jegy: ${quiz.lastGrade}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),

          // Stats row for completed tests
          if (!isMissed) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatItem(
                  theme,
                  Icons.score_rounded,
                  'Pont',
                  '${quiz.totalScore.toStringAsFixed(1)} / ${quiz.totalMaxScore.toStringAsFixed(1)}',
                ),
                _buildStatItem(
                  theme,
                  Icons.percent_rounded,
                  'Átlag',
                  '${quiz.averagePercentage.toStringAsFixed(1)}%',
                ),
                _buildStatItem(
                  theme,
                  Icons.emoji_events_outlined,
                  'Legjobb',
                  '${quiz.bestPercentage.toStringAsFixed(1)}%',
                ),
                _buildStatItem(
                  theme,
                  Icons.repeat_rounded,
                  'Próbálkozás',
                  '${quiz.attempts}x',
                ),
              ],
            ),

            // Individual attempt details
            if (quiz.results.length > 1) ...[
              const SizedBox(height: 10),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 8),
              ...quiz.results.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final r = entry.value;
                final dateStr = r.date != null
                    ? DateFormat('yyyy.MM.dd HH:mm').format(r.date!)
                    : '–';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '$idx.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${r.score.toStringAsFixed(1)}/${r.maxScore.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _getGradeColor(
                            r.percentage,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${r.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getGradeColor(r.percentage),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (quiz.results.length == 1) ...[
              const SizedBox(height: 6),
              Text(
                quiz.results.first.date != null
                    ? 'Kitöltve: ${DateFormat('yyyy.MM.dd HH:mm').format(quiz.results.first.date!)}'
                    : '',
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RECENT RESULTS SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRecentResultsSection(ThemeData theme) {
    if (_allResults.isEmpty) return const SizedBox.shrink();

    final recentResults = _allResults.take(15).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Utolsó eredmények', Icons.history_rounded),
        const SizedBox(height: 12),
        ...recentResults.map((r) => _buildResultTile(theme, r)),
      ],
    );
  }

  Widget _buildResultTile(ThemeData theme, _TestResult result) {
    final dateStr = result.date != null
        ? DateFormat('yyyy.MM.dd HH:mm').format(result.date!)
        : '---';
    final color = _getGradeColor(result.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          // Percentage badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${result.percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + group
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  result.groupName,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Score + date + grade
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.score.toStringAsFixed(1)} / ${result.maxScore.toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dateStr,
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
              if (result.grade != null) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getGradeColor(
                      result.percentage,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Jegy: ${result.grade}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getGradeColor(result.percentage),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(double percentage) {
    if (percentage >= 85) return Colors.green;
    if (percentage >= 70) return Colors.lightGreen;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 30) return Colors.deepOrange;
    return Colors.red;
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════

class _GroupStats {
  final int groupId;
  final String groupName;
  final String? groupColor;
  final int totalQuizzes;
  final int completedQuizzes;
  final double averagePercentage;
  final double bestPercentage;
  final List<_TestResult> results;
  final List<_QuizDetailStats> quizDetails;

  _GroupStats({
    required this.groupId,
    required this.groupName,
    this.groupColor,
    required this.totalQuizzes,
    required this.completedQuizzes,
    required this.averagePercentage,
    required this.bestPercentage,
    required this.results,
    required this.quizDetails,
  });
}

class _QuizDetailStats {
  final int quizId;
  final String title;
  final int attempts;
  final double averagePercentage;
  final double bestPercentage;
  final double totalScore;
  final double totalMaxScore;
  final int? lastGrade;
  final List<_TestResult> results;

  _QuizDetailStats({
    required this.quizId,
    required this.title,
    required this.attempts,
    required this.averagePercentage,
    required this.bestPercentage,
    required this.totalScore,
    required this.totalMaxScore,
    this.lastGrade,
    required this.results,
  });
}

class _TestResult {
  final int quizId;
  final String title;
  final String groupName;
  final double score;
  final double maxScore;
  final double percentage;
  final int? grade;
  final DateTime? date;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final int? questionCount;
  final int? timeLimitMinutes;

  _TestResult({
    required this.quizId,
    required this.title,
    required this.groupName,
    required this.score,
    required this.maxScore,
    required this.percentage,
    this.grade,
    this.date,
    this.dateStart,
    this.dateEnd,
    this.questionCount,
    this.timeLimitMinutes,
  });
}
