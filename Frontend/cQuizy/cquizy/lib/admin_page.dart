import 'package:flutter/material.dart';
import 'dart:async';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:printing/printing.dart';
import 'services/pdf_service.dart';
import 'theme.dart';
import 'grading_view.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

const double kAdminDesktopBreakpoint = 700.0;

class AdminPage extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final String? groupName;

  const AdminPage({super.key, required this.quiz, this.groupName});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _selectedSection = 'Felügyelet';

  // State
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  // Mock data for monitoring (Legacy, keeping reference if needed but unused)
  Map<String, dynamic>? _fullQuizData;
  bool _isLoadingDetails = true;

  // Export Configuration State
  bool _exportIncludeStats = true;
  bool _exportIncludeStudentList = true;
  bool _exportIncludeStudentDetails = false;
  bool _exportIncludeQuestions = false;
  bool _exportIncludeWarnings = false;
  String _exportWarningLayout = 'grouped'; // 'grouped' or 'abc'

  // --- New Export Options (20+) ---
  // Layout
  String _optOrientation = 'portrait'; // 'portrait', 'landscape'
  String _optPageSize = 'a4'; // 'a4', 'letter'
  String _optFontSize = 'normal'; // 'normal', 'large'
  bool _optCompactMode = false;

  // Table Formatting
  bool _optRowNumbering = false;
  bool _optStripedRows = true;
  bool _optShowBorders = true;

  // Header/Footer/Extras
  String _optWatermark = '';
  bool _optTimestamp = true;
  bool _optPageNumbers = true;
  bool _optSignature = false;
  bool _optCoverPage = false;
  String _optCustomNote = '';

  // Privacy & Student Data
  bool _optAnonymize = false;
  bool _optShowStudentId = false;
  bool _optPassFail = false;
  bool _optFeedbackBox = false;

  // Content Specifics
  bool _optAnswerKey = false;
  bool _optShowPoints = true;
  bool _optOnlyIncorrect = false;
  bool _optHideCorrect = false;
  bool _optGrayscale = false;

  @override
  void initState() {
    super.initState();
    _fetchProjectDetails();
    _fetchData();
    // Poll every 10 seconds
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchData(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();
    final quizId = widget.quiz['id'];

    if (quizId == null) return;

    try {
      // Fetch submissions
      final submissions = await api.getQuizSubmissions(token, quizId);
      // Fetch events/alerts
      final events = await api.getQuizEvents(token, quizId);

      // Merge data to create the member list
      // In a real scenario, we should also fetch the Group Members to show those who haven't started.
      // For now, we show those with submissions or events.

      final Map<String, Map<String, dynamic>> studentMap = {};

      // Process submissions
      for (var sub in submissions) {
        final userId = sub['user_id'].toString(); // Assuming user_id exists
        // Normalize status
        String status = 'writing';
        if (sub['finished_at'] != null) status = 'submitted';

        // Calculate score if available
        // ...

        studentMap[userId] = {
          'name':
              sub['user_name'] ??
              'Diák $userId', // Replace with real name if available
          'status': status,
          'wasBlocked': false, // Default
          'score': sub['score'] ?? 0,
          'maxScore': 100, // Should come from quiz details
          'grade': sub['grade'],
          'profilePicture':
              sub['user_avatar'] ?? 'https://i.pravatar.cc/150?u=$userId',
          'submission_id': sub['id'],
          'user_id': sub['user_id'],
        };
      }

      // Process events to update status (blocked, etc)
      for (var event in events) {
        final userId = event['user_id'].toString();
        if (!studentMap.containsKey(userId)) continue;

        if (event['type'] == 'blur' || event['type'] == 'cheat') {
          studentMap[userId]!['wasBlocked'] = true;
          if (event['resolved'] != true) {
            studentMap[userId]!['status'] = 'blocked';
          }
        }
      }

      if (mounted) {
        setState(() {
          _members = studentMap.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProjectDetails() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();
    // Assuming widget.quiz['id'] or widget.quiz['project_id'] exists
    final projectId = widget.quiz['id'] ?? widget.quiz['project_id'];
    if (projectId == null) {
      setState(() => _isLoadingDetails = false);
      return;
    }

    try {
      final data = await api.getProjectDetails(token, projectId);
      if (mounted) {
        setState(() {
          _fullQuizData = data;
          _isLoadingDetails = false;
          _generateMockAnswers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _generateMockAnswers() {
    if (_fullQuizData == null || _fullQuizData!['blocks'] == null) return;
    final blocks = _fullQuizData!['blocks'] as List;

    // Assign mock answers to each student
    for (var member in _members) {
      final answers = <Map<String, dynamic>>[];
      for (var block in blocks) {
        // Randomly decide if student answered correctly, incorrectly, or skipped
        // Simple logic: if grade is high, mostly correct
        // For now just mock some data
        answers.add({
          'question_id': block['id'],
          'question_text': block['question'],
          'answer_text': 'Mock answer for ${block['question']}',
          'is_correct': member['grade'] != null && member['grade'] > 3,
        });
      }
      member['mock_answers'] = answers;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDetails) {
      return Scaffold(
        body: Center(
          child: LoadingAnimationWidget.newtonCradle(
            color: Theme.of(context).primaryColor,
            size: 80,
          ),
        ),
      );
    }
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > kAdminDesktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 250,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 250,
                      child: _buildSidebar(context, isDesktop: true),
                    ),
                  ),
                ),
                Expanded(child: _buildContent(context, isDesktop: true)),
              ],
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: Drawer(
              child: SafeArea(child: _buildSidebar(context, isDesktop: false)),
            ),
            body: SafeArea(child: _buildContent(context, isDesktop: false)),
          );
        }
      },
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: isDesktop
            ? const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin felület',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.quiz['project_name'] ?? 'Névtelen teszt',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.groupName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.groupName!,
                    style: TextStyle(
                      color: theme
                          .primaryColor, // Use primary color for importance
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          Divider(color: theme.dividerColor, height: 20),
          _buildNavItem(
            context,
            'Felügyelet',
            Icons.remove_red_eye_outlined,
            isDesktop: isDesktop,
          ),
          _buildNavItem(
            context,
            'Beadott dolgozatok',
            Icons.assignment_turned_in_outlined,
            isDesktop: isDesktop,
          ),
          _buildNavItem(
            context,
            'Jegyek',
            Icons.grade_outlined,
            isDesktop: isDesktop,
          ),
          _buildNavItem(
            context,
            'Exportálás',
            Icons.file_download_outlined,
            isDesktop: isDesktop,
          ),

          const Spacer(),

          // Back Button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: InkWell(
              onTap: () {
                if (!isDesktop) {
                  // Mobile: First close the drawer
                  Navigator.of(context).pop();
                }
                // Then navigate back from the admin page
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withValues(alpha: 0.1),
                      theme.primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Vissza',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon, {
    VoidCallback? onTap,
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedSection == title && onTap == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? theme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            final themeProvider = ThemeInherited.of(context);
            themeProvider.triggerHaptic();
            if (onTap != null) {
              onTap();
            } else {
              setState(() {
                _selectedSection = title;
              });
              if (!isDesktop) {
                Navigator.of(context).pop(); // Close drawer on mobile
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.iconTheme.color?.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Top bar with menu/collapse toggle
            Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: isDesktop ? 16 : 24,
                bottom: isDesktop ? 0 : 12,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: isDesktop
                    ? null
                    : Border(
                        bottom: BorderSide(color: theme.dividerColor, width: 1),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // On mobile, show only section name (full width)
                  if (!isDesktop) ...[
                    Text(
                      _selectedSection,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      _selectedSection,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 1,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildSectionContent(context)),
          ],
        ),

        // Floating Back Button for mobile if needed, or menu button
        if (!isDesktop)
          Positioned(
            bottom: 24,
            left: 24,
            child: Builder(
              builder: (context) {
                return Tooltip(
                  message: 'Menü',
                  child: InkWell(
                    onTap: () {
                      Scaffold.of(context).openDrawer();
                    },
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    if (_selectedSection == 'Felügyelet') {
      return _buildMonitoringSection(context);
    } else if (_selectedSection == 'Beadott dolgozatok') {
      return _buildSubmittedExamsSection(context);
    } else if (_selectedSection == 'Jegyek') {
      return _buildGradesSection(context);
    } else if (_selectedSection == 'Exportálás') {
      return _buildExportSection(context);
    }

    // Placeholder for other sections
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForSection(_selectedSection),
            size: 64,
            color: Theme.of(context).hintColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '$_selectedSection tartalom hamarosan...',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGradesSection(BuildContext context) {
    final theme = Theme.of(context);
    // Filter graded students
    final gradedStudents = _members.where((m) => m['grade'] != null).toList();

    // Calculate Stats
    final gradeCounts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    double totalGradeSum = 0;

    for (var m in gradedStudents) {
      final g = m['grade'] as int;
      gradeCounts[g] = (gradeCounts[g] ?? 0) + 1;
      totalGradeSum += g;
    }

    final double average = gradedStudents.isNotEmpty
        ? totalGradeSum / gradedStudents.length
        : 0.0;

    final int missingCount = _members.length - gradedStudents.length;

    // Determine max frequency for distribution bar
    int maxFreq = 0;
    gradeCounts.forEach((k, v) {
      if (v > maxFreq) maxFreq = v;
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Panel
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statisztika',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top Stats Row (Total, Avg, Count, Missing)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildSummaryItem(
                          context,
                          'Összesen',
                          '${_members.length} fő',
                          theme.textTheme.bodyLarge?.color ?? Colors.black,
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryItem(
                          context,
                          'Átlag',
                          average.toStringAsFixed(2),
                          Colors.blue,
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryItem(
                          context,
                          'Beadta',
                          '${gradedStudents.length} fő',
                          Colors.green,
                        ),
                        const SizedBox(width: 24),
                        _buildSummaryItem(
                          context,
                          'Hiányzik',
                          '$missingCount fő',
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Distribution Header
                  Text(
                    'Jegyek eloszlása',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Distribution Bars
                  Row(
                    children: [
                      for (int i = 1; i <= 5; i++)
                        Expanded(
                          child: _buildDistributionBar(
                            context,
                            grade: i,
                            count: gradeCounts[i] ?? 0,
                            total: gradedStudents.length,
                            isMostFrequent:
                                maxFreq > 0 && gradeCounts[i] == maxFreq,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Student List Header
          Text(
            'Tanulók eredményei',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),

          // Student List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final grade = member['grade'] as int?;
              final score = member['score'] as int? ?? 0;
              final maxScore = member['maxScore'] as int? ?? 100;
              final percent = maxScore > 0
                  ? (score / maxScore * 100).round()
                  : 0;
              final profilePic = member['profilePicture'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    backgroundImage: profilePic != null && profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : null,
                    child: profilePic == null || profilePic.isEmpty
                        ? Text(
                            member['name'][0].toUpperCase(),
                            style: TextStyle(color: theme.primaryColor),
                          )
                        : null,
                  ),
                  title: Text(
                    member['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: grade != null
                      ? Text('$score / $maxScore pont ($percent%)')
                      : const Text(
                          'Nincs osztályozva',
                          style: TextStyle(color: Colors.grey),
                        ),
                  trailing: grade != null
                      ? Text(
                          grade.toString(),
                          style: TextStyle(
                            color: _getGradeColor(grade),
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        )
                      : Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade300,
                          size: 32,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  Widget _buildDistributionBar(
    BuildContext context, {
    required int grade,
    required int count,
    required int total,
    required bool isMostFrequent,
  }) {
    final theme = Theme.of(context);
    final double flex = total > 0 ? count / total : 0;

    return Column(
      children: [
        Container(
          height: 120, // Increased height for better visibility
          width: 40, // Explicit width for the track
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(
              0.05,
            ), // Subtle track background
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 40,
                height: 120 * flex + (count > 0 ? 5 : 0),
                decoration: BoxDecoration(
                  color: isMostFrequent
                      ? theme.primaryColor
                      : theme.primaryColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isMostFrequent
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -20, // Floating label above the bar
                  child: Text(
                    '${(flex * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.hintColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 32, // Fixed size for perfect circle
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _getGradeColor(grade).withOpacity(0.2), // Always faint color
            shape: BoxShape.circle,
          ),
          child: Text(
            '$grade',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _getGradeColor(grade),
            ),
          ), // Always colored text
        ),
        const SizedBox(height: 4),
        Text(
          '$count db',
          style: TextStyle(
            fontSize: 13, // Increased font size
            color: isMostFrequent
                ? theme.textTheme.bodyLarge?.color
                : theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.bold, // Always bold for visibility
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(int grade) {
    switch (grade) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.deepOrange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSubmittedExamsSection(BuildContext context) {
    final theme = Theme.of(context);

    final submittedGroup = _members
        .where((m) => m['status'] == 'submitted' || m['status'] == 'closed')
        .toList();

    final notSubmittedGroup = _members
        .where((m) => m['status'] != 'submitted' && m['status'] != 'closed')
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // 1. LEADTA A TESZTET
              if (submittedGroup.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Leadta a tesztet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${submittedGroup.length}',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...submittedGroup.map((member) => _buildStudentCard(member)),
                const SizedBox(height: 32),
              ],

              // 2. NEM ADTA LE A TESZTET
              if (notSubmittedGroup.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.highlight_off, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      'Nem adta le a tesztet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notSubmittedGroup.length}',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...notSubmittedGroup.map(
                  (member) => _buildStudentCard(member, showStatus: false),
                ),
                const SizedBox(height: 100), // Space for FAB
              ],
            ],
          ),
        ),
        // Bottom Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 80), // Space for menu button
              child: SizedBox(
                width: 250,
                height: 56, // Match Menu button height
                child: ElevatedButton.icon(
                  onPressed: submittedGroup.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GradingView(
                                student: submittedGroup.first,
                                quizTitle:
                                    widget.quiz['project_name'] ?? 'Teszt',
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note, size: 24),
                  label: const Text(
                    'Dolgozatok javítása',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> member, {
    bool showStatus = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundImage: NetworkImage(member['profilePicture']),
          onBackgroundImageError: (_, __) {},
          child: Text(member['name'][0]),
        ),
        title: Text(
          member['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: showStatus
            ? Text(
                _getStatusText(member['status']),
                style: TextStyle(color: _getStatusColor(member['status'])),
              )
            : null,
        trailing:
            (member['status'] == 'submitted' || member['status'] == 'closed')
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${member['score']} / ${member['maxScore']} pont',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Jegy: 4',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              )
            : null,
        onTap: null, // Disabled click as requested
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'submitted':
        return 'Leadva';
      case 'closed':
        return 'Lezárva';
      case 'writing':
        return 'Írja...';
      case 'blocked':
        return 'Letiltva';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.green;
      case 'closed':
        return Colors.red;
      case 'writing':
        return Colors.blue;
      case 'blocked':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMonitoringSection(BuildContext context) {
    // Csak azokat jelenítjük meg, akik már elkezdték (nem 'idle')
    final activeMembers = _members.where((m) => m['status'] != 'idle').toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildDashboardBar(context),
          const SizedBox(height: 24),
          Expanded(
            child: activeMembers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).disabledColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Még senki sem kezdte el a tesztet.',
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: activeMembers.length,
                    itemBuilder: (context, index) {
                      return _buildMemberCard(context, activeMembers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBar(BuildContext context) {
    final theme = Theme.of(context);
    final writingCount = _members.where((m) => m['status'] == 'writing').length;
    final blockedCount = _members.where((m) => m['status'] == 'blocked').length;
    final submittedCount = _members
        .where((m) => m['status'] == 'submitted')
        .length;
    final closedCount = _members.where((m) => m['status'] == 'closed').length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              if (isWide) {
                // Desktop / Wide Layout (Original Row)
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Timer
                      Icon(
                        Icons.timer_outlined,
                        color: theme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "45:00",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_time, size: 28),
                        tooltip: "+5 perc",
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 24),

                      // Stats
                      _buildStatItem(
                        context,
                        Icons.edit_note,
                        writingCount,
                        Colors.grey,
                        "Írják",
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        context,
                        Icons.block,
                        blockedCount,
                        Colors.amber,
                        "Tiltva",
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        context,
                        Icons.check_circle_outline,
                        submittedCount,
                        Colors.green,
                        "Leadta",
                      ),
                      const SizedBox(width: 16),
                      _buildStatItem(
                        context,
                        Icons.lock_clock,
                        closedCount,
                        Colors.red,
                        "Lezárva",
                      ),

                      const SizedBox(width: 32),

                      // Actions
                      _buildDashboardActions(context),
                    ],
                  ),
                );
              } else {
                // Mobile / Narrow Layout (Vertical + Wrap)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Timer Centered + Refresh Right
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.more_time, size: 28),
                            tooltip: "+5 perc",
                            color: theme.primaryColor,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: theme.primaryColor,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "45:00",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.refresh, size: 28),
                            tooltip: "Frissítés",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats Row (Horizontal)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            context,
                            Icons.edit_note,
                            writingCount,
                            Colors.grey,
                            "Írják",
                          ),
                          _buildStatItem(
                            context,
                            Icons.block,
                            blockedCount,
                            Colors.amber,
                            "Tiltva",
                          ),
                          _buildStatItem(
                            context,
                            Icons.check_circle_outline,
                            submittedCount,
                            Colors.green,
                            "Leadta",
                          ),
                          _buildStatItem(
                            context,
                            Icons.lock_clock,
                            closedCount,
                            Colors.red,
                            "Lezárva",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions wrapped (Unblock/Close all)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.lock_open, size: 22),
                            label: const Text(
                              "Feloldás", // Shortened label for mobile
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.amber.shade800,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 22,
                            ),
                            label: const Text(
                              "Lezárás", // Shortened label for mobile
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.red,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ),
        Container(
          height: 1,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
        ),
      ],
    );
  }

  // Helper for actions to avoid code duplication in wide mode
  Widget _buildDashboardActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Unblock All
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.lock_open, size: 22),
          label: const Text("Összes feloldása", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.withValues(alpha: 0.1),
            foregroundColor: Colors.amber.shade800,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(width: 12),
        // Close All
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.stop_circle_outlined, size: 22),
          label: const Text("Összes lezárása", style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            foregroundColor: Colors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(width: 12),
        // Refresh
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.refresh, size: 28),
          tooltip: "Frissítés",
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    int count,
    Color color,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, color: color, size: 28), // Increased form 24 to 28
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20, // Increased from 18 to 20
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final status = member['status'] as String;
    final wasBlocked = member['wasBlocked'] as bool;
    final isFinished = status == 'submitted' || status == 'closed';

    // Determine colors and icon based on status
    Color borderColor;
    IconData statusIcon;
    Color iconColor;

    switch (status) {
      case 'writing':
        borderColor = Colors.grey;
        statusIcon = Icons.edit_note;
        iconColor = Colors.grey;
        break;
      case 'blocked':
        borderColor = Colors.yellow;
        statusIcon = Icons.block;
        iconColor = Colors.yellow;
        break;
      case 'closed':
        borderColor = Colors.red;
        statusIcon = Icons.lock_clock;
        iconColor = Colors.red;
        break;
      case 'submitted':
        borderColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      default:
        borderColor = Colors.grey;
        statusIcon = Icons.help_outline;
        iconColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          borderColor.withValues(alpha: 0.05),
          theme.cardColor,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 10.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Slot 1: Profile Picture
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(member['profilePicture']),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                // Slot 2: Name (Fixed height)
                SizedBox(
                  height: 26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          member['name'],
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status Indicators Logic
                      if (status == 'submitted' && !wasBlocked) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Leadta (Tiszta)",
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                        ),
                      ] else if (status == 'submitted' && wasBlocked) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Leadta (Volt tiltva)",
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 18,
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ] else if (status == 'writing' && wasBlocked) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Írja (Volt tiltva)",
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                      ] else if (status == 'closed' && wasBlocked) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Lezárva (Volt tiltva)",
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_clock,
                                color: Colors.red,
                                size: 18,
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ] else if (status == 'closed' && !wasBlocked) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: "Lezárva",
                          child: Icon(
                            Icons.lock_clock,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Slot 3: Button Row 1 or Score
                SizedBox(
                  height: 32,
                  child: Center(
                    child: _buildSlot1Content(
                      member,
                      status,
                      isFinished,
                      theme,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Slot 4: Button Row 2 (if exists) or Metadata
                SizedBox(
                  height: 32,
                  child: Center(
                    child: _buildSlot2Content(
                      member,
                      status,
                      wasBlocked,
                      theme,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(statusIcon, color: iconColor, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot1Content(
    Map<String, dynamic> member,
    String status,
    bool isFinished,
    ThemeData theme,
  ) {
    if (status == 'writing' || status == 'blocked') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              member['status'] = 'closed';
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            foregroundColor: Colors.red,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Lezárás',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (isFinished) {
      return Text(
        '${member['score']} / ${member['maxScore']} pont',
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Fallback status text
    return Text(
      status == 'closed' ? 'Lezárva' : (status == 'submitted' ? 'Leadta' : ''),
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSlot2Content(
    Map<String, dynamic> member,
    String status,
    bool wasBlocked,
    ThemeData theme,
  ) {
    if (status == 'blocked') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              member['status'] = 'writing';
              member['wasBlocked'] = true;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.1),
            foregroundColor: Colors.green,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Engedélyezés',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (wasBlocked && status != 'blocked') {
      return Text(
        'Volt letiltva',
        style: TextStyle(
          color: Colors.orange.withValues(alpha: 0.8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Map<String, dynamic> _calculateStats() {
    int total = _members.length;
    int submitted = _members
        .where((m) => m['status'] == 'closed' || m['status'] == 'submitted')
        .length;
    int rated = _members.where((m) => m['grade'] != null).length;

    double average = 0;
    if (rated > 0) {
      final sum = _members
          .where((m) => m['grade'] != null)
          .fold(0, (prev, m) => prev + (m['grade'] as int));
      average = sum / rated;
    }

    Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var m in _members) {
      if (m['grade'] != null) {
        int g = m['grade'];
        distribution[g] = (distribution[g] ?? 0) + 1;
      }
    }

    return {
      'total': total,
      'submitted': submitted,
      'average': average,
      'distribution': distribution,
    };
  }

  Widget _buildExportSection(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _calculateStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exportálási beállítások',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tartalom',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildExportToggle(
                    'Statisztikák (átlag, eloszlás)',
                    _exportIncludeStats,
                    (value) => setState(() => _exportIncludeStats = value),
                  ),
                  _buildExportToggle(
                    'Tanulók listája (név, pontszám, jegy)',
                    _exportIncludeStudentList,
                    (value) =>
                        setState(() => _exportIncludeStudentList = value),
                  ),
                  _buildExportToggle(
                    'Tanulói részletek (válaszok, idő)',
                    _exportIncludeStudentDetails,
                    (value) =>
                        setState(() => _exportIncludeStudentDetails = value),
                  ),
                  _buildExportToggle(
                    'Kérdések és helyes válaszok',
                    _exportIncludeQuestions,
                    (value) => setState(() => _exportIncludeQuestions = value),
                  ),
                  _buildExportToggle(
                    'Tanulói Státuszok (pl. Leadta, Letiltva)',
                    _exportIncludeWarnings,
                    (value) => setState(() => _exportIncludeWarnings = value),
                  ),
                ],
              ),
            ),
          ),
          // --- Advanced Settings ---
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Bővített beállítások',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
                leading: Icon(Icons.tune, color: theme.primaryColor),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  // 1. Megjelenés (Layout)
                  _buildSettingsGroup('Megjelenés', [
                    _buildDropdown(
                      'Tájolás',
                      _optOrientation,
                      ['portrait', 'landscape'],
                      ['Álló', 'Fekvő'],
                      (v) => setState(() => _optOrientation = v!),
                    ),
                    _buildSettingsGroupToggle(
                      'Kompakt mód',
                      _optCompactMode,
                      (v) => setState(() => _optCompactMode = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Szürkeárnyalatos',
                      _optGrayscale,
                      (v) => setState(() => _optGrayscale = v),
                    ),
                  ]),
                  const Divider(),

                  // 2. Táblázatok (Tables)
                  _buildSettingsGroup('Táblázatok', [
                    _buildSettingsGroupToggle(
                      'Sorszámozás',
                      _optRowNumbering,
                      (v) => setState(() => _optRowNumbering = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Zebra csíkozás',
                      _optStripedRows,
                      (v) => setState(() => _optStripedRows = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Szegélyek megjelenítése',
                      _optShowBorders,
                      (v) => setState(() => _optShowBorders = v),
                    ),
                  ]),
                  const Divider(),

                  // 3. Adatvédelem (Privacy)
                  _buildSettingsGroup('Adatvédelem', [
                    _buildSettingsGroupToggle(
                      'Névtelenítés',
                      _optAnonymize,
                      (v) => setState(() => _optAnonymize = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Pass/Fail kiemelés',
                      _optPassFail,
                      (v) => setState(() => _optPassFail = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Tanuló ID mutatása',
                      _optShowStudentId,
                      (v) => setState(() => _optShowStudentId = v),
                    ),
                  ]),
                  const Divider(),

                  // 4. Extrák (Extras)
                  _buildSettingsGroup('Extrák', [
                    _buildSettingsGroupToggle(
                      'Aláírás helye',
                      _optSignature,
                      (v) => setState(() => _optSignature = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Létrehozás ideje',
                      _optTimestamp,
                      (v) => setState(() => _optTimestamp = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Címlap',
                      _optCoverPage,
                      (v) => setState(() => _optCoverPage = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Megoldókulcs (végén)',
                      _optAnswerKey,
                      (v) => setState(() => _optAnswerKey = v),
                    ),
                    _buildSettingsGroupToggle(
                      'Csak hibás válaszok',
                      _optOnlyIncorrect,
                      (v) => setState(() => _optOnlyIncorrect = v),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _optCustomNote = v),
                    decoration: InputDecoration(
                      labelText: 'Megjegyzés a lábléchez',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: SizedBox(
              width: 250,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final pdf = await PdfService.generateGradesReport(
                    quizTitle: widget.quiz['project_name'] ?? 'Teszt',
                    groupName: widget.groupName ?? '',
                    students: _members,
                    stats: stats,
                    quizData: _fullQuizData,
                    includeStats: _exportIncludeStats,
                    includeStudentList: _exportIncludeStudentList,
                    includeStudentDetails: _exportIncludeStudentDetails,
                    includeQuestions: _exportIncludeQuestions,
                    includeWarnings: _exportIncludeWarnings,
                    warningLayout: _exportWarningLayout,
                    // New Options passed as a Map to avoid huge argument list
                    options: {
                      'orientation': _optOrientation,
                      'rowNumbering': _optRowNumbering,
                      'stripedRows': _optStripedRows,
                      'showBorders': _optShowBorders,
                      'anonymize': _optAnonymize,
                      'signature': _optSignature,
                      'timestamp': _optTimestamp,
                      'coverPage': _optCoverPage,
                      'answerKey': _optAnswerKey,
                      'onlyIncorrect': _optOnlyIncorrect,
                      'grayscale': _optGrayscale,
                      'compactMode': _optCompactMode,
                      'customNote': _optCustomNote,
                      'passFail': _optPassFail,
                      // Missing options added
                      'pageSize': _optPageSize,
                      'fontSize': _optFontSize,
                      'watermark': _optWatermark,
                      'pageNumbers': _optPageNumbers,
                      'feedbackBox': _optFeedbackBox,
                      'showPoints': _optShowPoints,
                      'hideCorrect': _optHideCorrect,
                      'showStudentId': _optShowStudentId,
                    },
                  );
                  Printing.sharePdf(
                    bytes: pdf,
                    filename:
                        '${widget.quiz['project_name'] ?? 'Teszt'}_admin_report.pdf',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 24),
                label: const Text(
                  'PDF generálása',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportToggle(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  // Helper widgets for settings
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingsGroupToggle(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            height: 24,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String title,
    String value,
    List<String> items,
    List<String> labels,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13)),
        DropdownButton<String>(
          value: value,
          items: List.generate(items.length, (index) {
            return DropdownMenuItem(
              value: items[index],
              child: Text(labels[index], style: const TextStyle(fontSize: 13)),
            );
          }),
          onChanged: onChanged,
          underline: Container(),
        ),
      ],
    );
  }

  IconData _getIconForSection(String section) {
    switch (section) {
      case 'Felügyelet':
        return Icons.remove_red_eye_outlined;
      case 'Beadott dolgozatok':
        return Icons.assignment_turned_in_outlined;
      case 'Jegyek':
        return Icons.grade_outlined;
      case 'Exportálás':
        return Icons.file_download_outlined;
      default:
        return Icons.construction;
    }
  }
}
