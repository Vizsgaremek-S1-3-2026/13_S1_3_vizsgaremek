import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

class GradingView extends StatefulWidget {
  final Map<String, dynamic> student;
  final String quizTitle;

  final int grade2Limit;
  final int grade3Limit;
  final int grade4Limit;
  final int grade5Limit;

  const GradingView({
    super.key,
    required this.student,
    required this.quizTitle,
    this.grade2Limit = 40,
    this.grade3Limit = 55,
    this.grade4Limit = 70,
    this.grade5Limit = 85,
    this.quizBlocks,
  });

  final List<dynamic>? quizBlocks;

  @override
  State<GradingView> createState() => _GradingViewState();
}

class GradingSubmission {
  final int id; // submitted_answer_id
  final String question;
  final String userAnswer;
  final String correctAnswer;
  final List<String>? alternativeAnswers;
  int awardedPoints;
  int maxPoints;
  String? teacherComment;

  GradingSubmission({
    required this.id,
    required this.question,
    required this.userAnswer,
    required this.correctAnswer,
    this.alternativeAnswers,
    required this.awardedPoints,
    required this.maxPoints,
    this.teacherComment,
  });
}

class _GradingViewState extends State<GradingView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  late final ScrollController _scrollController;
  List<GradingSubmission> _submissions = [];
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _showStatisticsPanel = false;
  String _debugMessage = '';

  int _manualGradeOffset = 0;

  // Grade thresholds
  late int _grade5Min;
  late int _grade4Min;
  late int _grade3Min;
  late int _grade2Min;

  bool get _isGrade5Valid => _grade5Min > _grade4Min && _grade5Min <= 100;
  bool get _isGrade4Valid => _grade4Min > _grade3Min && _grade4Min < _grade5Min;
  bool get _isGrade3Valid => _grade3Min > _grade2Min && _grade3Min < _grade4Min;
  bool get _isGrade2Valid => _grade2Min >= 1 && _grade2Min < _grade3Min;
  bool get _areThresholdsValid =>
      _isGrade5Valid && _isGrade4Valid && _isGrade3Valid && _isGrade2Valid;

  // Current student - can be switched from the student list
  late Map<String, dynamic> _selectedStudent;

  Map<String, dynamic> get _currentStudent => _selectedStudent;

  String get _cheatingStatus =>
      _currentStudent['cheatingStatus']?.toString() ?? 'none';

  Map<String, dynamic> get _statistics {
    int totalQuestions = _submissions.length;
    int correctCount = 0;
    int partialCount = 0;
    int incorrectCount = 0;
    int totalMaxPoints = 0;
    int totalAwardedPoints = 0;

    for (var sub in _submissions) {
      totalMaxPoints += sub.maxPoints;
      totalAwardedPoints += sub.awardedPoints;

      if (sub.awardedPoints == sub.maxPoints) {
        correctCount++;
      } else if (sub.awardedPoints == 0) {
        incorrectCount++;
      } else {
        partialCount++;
      }
    }

    double percentage = totalMaxPoints > 0
        ? (totalAwardedPoints / totalMaxPoints) * 100
        : 0.0;

    return {
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'partialCount': partialCount,
      'incorrectCount': incorrectCount,
      'totalMaxPoints': totalMaxPoints,
      'totalAwardedPoints': totalAwardedPoints,
      'percentage': percentage,
    };
  }

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student;
    _grade2Min = widget.grade2Limit;
    _grade3Min = widget.grade3Limit;
    _grade4Min = widget.grade4Limit;
    _grade5Min = widget.grade5Limit;
    _scrollController = ScrollController();

    _fetchSubmissionDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Adjust _manualGradeOffset so _finalGrade matches the student's saved grade_value from API
  void _initGradeOffsetFromStudent() {
    final gradeRaw = _selectedStudent['grade'];
    if (gradeRaw == null) return;
    final savedGrade = int.tryParse(gradeRaw.toString());
    if (savedGrade == null) return;
    // _calculatedGrade is based on points, savedGrade is what the API already has
    // Offset = savedGrade - calculatedGrade
    final offset = (savedGrade - _calculatedGrade).clamp(-4, 4);
    if (_manualGradeOffset != offset) {
      setState(() {
        _manualGradeOffset = offset;
      });
    }
  }

  Future<void> _fetchSubmissionDetails() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final submissionIdRaw = _selectedStudent['submission_id'];
    final int? submissionId = submissionIdRaw != null
        ? int.tryParse(submissionIdRaw.toString())
        : null;

    debugPrint('=== GradingView _fetchSubmissionDetails ===');
    debugPrint('Student keys: ${_selectedStudent.keys.toList()}');
    debugPrint('Student data: $_selectedStudent');
    debugPrint('submission_id: $submissionId');
    if (submissionId == null) {
      if (mounted) {
        setState(() {
          _submissions = [];
          _isLoading = false;
          _debugMessage =
              'Ehhez a diákhoz nincs beadott dolgozat (submission_id hiányzik).\n'
              'Diák adatai: ${_selectedStudent.keys.toList()}';
        });
      }
      return;
    }

    final api = ApiService();
    final details = await api.getSubmissionDetails(token, submissionId);
    debugPrint('getSubmissionDetails result: $details');

    if (details != null && mounted) {
      final answers = details['answers'] as List<dynamic>? ?? [];
      debugPrint('answers count: ${answers.length}');
      if (answers.isNotEmpty) {
        debugPrint(
          '=== FIRST ANSWER KEYS: ${(answers.first as Map).keys.toList()} ===',
        );
        debugPrint('=== FIRST ANSWER DATA: ${answers.first} ===');
        if (mounted) {
          setState(() {
            _debugMessage =
                'DEBUG KEYS: ${(answers.first as Map).keys.toList()}\nDATA: ${answers.first}';
          });
        }
      }

      setState(() {
        _submissions = answers.map((a) {
          // Directly use max_points from API response
          int maxPoints = 0;
          final rawMax = a['max_points'];
          if (rawMax != null) {
            maxPoints = (rawMax as num).toInt();
          }

          int awardedPoints = 0;
          final rawAwarded = a['points_awarded'];
          if (rawAwarded != null) {
            awardedPoints = (rawAwarded as num).toInt();
          }

          // If max_points not in API response, try finding in quizBlocks
          if (maxPoints == 0 && widget.quizBlocks != null) {
            final blockId = a['block_id'];
            try {
              final block = widget.quizBlocks!.firstWhere(
                (b) => b['id'] == blockId,
              );
              if (block.containsKey('answers')) {
                int sum = 0;
                final blockAnswers = block['answers'] as List<dynamic>? ?? [];
                for (var opt in blockAnswers) {
                  if (opt['points'] != null) {
                    final p = (opt['points'] as num).toInt();
                    if (p > 0) sum += p;
                  }
                }
                maxPoints = sum;
              }
            } catch (_) {}
          }

          // Fallback: if still 0, use awarded points (at least shows something)
          if (maxPoints == 0) maxPoints = awardedPoints > 0 ? awardedPoints : 1;

          // Build correct answer string from block data
          String correctAnswer = '';
          List<String>? alternativeAnswers;
          if (widget.quizBlocks != null) {
            final blockId = a['block_id'];
            try {
              final block = widget.quizBlocks!.firstWhere(
                (b) => b['id'] == blockId,
              );
              final blockAnswers = block['answers'] as List<dynamic>? ?? [];
              final correctOpts = blockAnswers
                  .where((ans) => ans['is_correct'] == true)
                  .toList();
              if (correctOpts.isNotEmpty) {
                correctAnswer =
                    correctOpts.first['answer_text']?.toString() ?? '';
                if (correctOpts.length > 1) {
                  alternativeAnswers = correctOpts
                      .skip(1)
                      .map((ans) => ans['answer_text']?.toString() ?? '')
                      .toList();
                }
              }
            } catch (_) {}
          }

          // Format student_answer: API may return string, list, bool, or JSON-encoded string
          String userAnswer;
          final raw =
              a['student_answer'] ??
              a['answer_text'] ??
              a['answer'] ??
              a['submitted_answer'];
          if (raw == null) {
            userAnswer = '(Nem válaszolt)';
          } else if (raw is bool) {
            userAnswer = raw ? 'Igaz' : 'Hamis';
          } else if (raw is List) {
            userAnswer = raw.map((e) => e.toString()).join(', ');
          } else {
            // Might be a JSON-encoded list string like '["answer"]'
            final str = raw.toString();
            if (str.isEmpty) {
              userAnswer = '(Nem válaszolt)';
            } else if (str.startsWith('[') && str.endsWith(']')) {
              try {
                final decoded = jsonDecode(str);
                if (decoded is List) {
                  userAnswer = decoded.map((e) => e.toString()).join(', ');
                } else {
                  userAnswer = str;
                }
              } catch (_) {
                userAnswer = str;
              }
            } else {
              userAnswer = str;
            }
          }

          return GradingSubmission(
            id: a['id'] ?? 0,
            question: a['block_question']?.toString() ?? 'Kérdés',
            userAnswer: userAnswer,
            correctAnswer: correctAnswer,
            alternativeAnswers: alternativeAnswers,
            awardedPoints: awardedPoints,
            maxPoints: maxPoints,
            teacherComment: a['teacher_comment']?.toString(),
          );
        }).toList();
        _isLoading = false;
        if (_submissions.isEmpty) {
          _debugMessage =
              'API call succeeded, but answers list is empty. Submission ID: $submissionId.';
          if (details.containsKey('detail') || details.containsKey('error')) {
            _debugMessage +=
                ' API Message: ${details['detail'] ?? details['error']}';
          }
        }
      });
      // After data loaded, sync grade offset to match saved grade_value
      _initGradeOffsetFromStudent();
    } else {
      if (mounted) {
        setState(() {
          _debugMessage =
              'API call failed or returned null for Submission ID: $submissionId.';
          _isLoading = false;
        });
      }
    }
  }

  int get _totalPoints =>
      _submissions.fold(0, (sum, item) => sum + item.awardedPoints);
  int get _maxPoints =>
      _submissions.fold(0, (sum, item) => sum + item.maxPoints);

  int get _calculatedGrade {
    if (_maxPoints == 0) return 1;
    final percentage = (_totalPoints / _maxPoints) * 100;
    if (percentage < _grade2Min) return 1;
    if (percentage < _grade3Min) return 2;
    if (percentage < _grade4Min) return 3;
    if (percentage < _grade5Min) return 4;
    return 5;
  }

  int get _finalGrade {
    int grade = _calculatedGrade + _manualGradeOffset;
    return grade.clamp(1, 5);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nem mentett változások'),
        content: const Text(
          'Biztosan ki szeretnél lépni? A módosítások elvesznek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Kilépés mentés nélkül'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  Future<void> _saveChanges() async {
    if (!_areThresholdsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Javítsd a ponthatárokat mentés előtt!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final int? submissionId = _selectedStudent['submission_id'] != null
        ? int.tryParse(_selectedStudent['submission_id'].toString())
        : null;
    if (submissionId == null) return;

    setState(() => _isLoading = true);
    final api = ApiService();

    // 1. Collect point updates
    // We send all points just to be safe, or we could track changes.
    // Sending all ensures consistency.
    final updates = _submissions.map((s) {
      return {'submitted_answer_id': s.id, 'new_points': s.awardedPoints};
    }).toList();

    bool pointsSuccess = true;
    if (updates.isNotEmpty) {
      pointsSuccess = await api.updateSubmissionPoints(token, submissionId, {
        'updates': updates,
      });
    }

    // 2. Update Grade (Override)
    // We calculate the grade locally based on the new points and offset
    bool gradeSuccess = true;
    // Only send grade update if we have a manual offset or just to sync the calculated grade
    // The requirement implies "Grade Override", so we send the final grade.
    final finalGrade = _finalGrade;
    gradeSuccess = await api.updateSubmissionGrade(
      token,
      submissionId,
      finalGrade,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (pointsSuccess && gradeSuccess) {
          _isEditing = false;
          _hasUnsavedChanges = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Változtatások sikeresen mentve!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hiba történt a mentés során!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Stack(
      children: [
        WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: theme.scaffoldBackgroundColor,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              toolbarHeight: 80,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Padding(
                padding: const EdgeInsets.only(top: 20.0, left: 8.0),
                child: Row(
                  children: [
                    // Show Back Button
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Vissza',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getStatusAttributes(_cheatingStatus)['icon']
                                    as IconData,
                                color:
                                    _getStatusAttributes(
                                          _cheatingStatus,
                                        )['color']
                                        as Color,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_getStatusAttributes(
                                                _cheatingStatus,
                                              )['color']
                                              as Color)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        (_getStatusAttributes(
                                                  _cheatingStatus,
                                                )['color']
                                                as Color)
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isDesktop
                                      ? (_getStatusAttributes(
                                              _cheatingStatus,
                                            )['text']?.toString() ??
                                            'Ismeretlen')
                                      : (_currentStudent['name']?.toString() ??
                                            'Diák'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        (_getStatusAttributes(
                                              _cheatingStatus,
                                            )['color']
                                            as Color),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.quizTitle,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Settings Panel (Desktop)
                            if (_isEditing)
                              _buildGradeSettingsPanel(theme, false),
                            Expanded(
                              child: _submissions.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Text(
                                          'Nincsenek válaszok a dolgozatban.\n\nDebug Info:\n$_debugMessage\n\nStudent Object keys: ${_selectedStudent.keys.join(", ")}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.5),
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                        left: 24,
                                        right: 24,
                                        top: 120,
                                        bottom: 120,
                                      ),
                                      itemCount: _submissions.length,
                                      itemBuilder: (context, index) {
                                        return _buildQuestionCard(
                                          _submissions[index],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: _submissions.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Text(
                                      'Nincsenek válaszok a dolgozatban.\n\nDebug Info:\n$_debugMessage',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.5),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 120,
                                    bottom: 120,
                                  ),
                                  itemCount: _submissions.length,
                                  itemBuilder: (context, index) {
                                    return _buildQuestionCard(
                                      _submissions[index],
                                    );
                                  },
                                ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomBar(),
                      ),
                    ],
                  ),
          ),
        ),
        _buildStatisticsPanel(),
      ],
    );
  }

  Widget _buildQuestionCard(GradingSubmission submission) {
    final theme = Theme.of(context);
    final isCorrect = submission.awardedPoints == submission.maxPoints;
    final isPartial =
        submission.awardedPoints > 0 &&
        submission.awardedPoints < submission.maxPoints;

    Color statusColor = Colors.red;
    if (isCorrect) statusColor = Colors.green;
    if (isPartial) statusColor = Colors.amber;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Question Number on Left and Points on Right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Question Number
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${submission.id}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                        // Points
                        _buildPointsEditor(submission),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Question Text
                    Text(
                      submission
                          .question, // Changed from questionTitle to question
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Student Answer
                    Text(
                      'Diák válasza:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: submission.userAnswer == '(Nem válaszolt)'
                          ? Text(
                              submission.userAnswer,
                              style: TextStyle(
                                color: theme.hintColor,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Text(
                              submission.userAnswer,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                    ),
                    if (submission.correctAnswer.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Helyes válasz:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        submission.correctAnswer,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsEditor(GradingSubmission submission) {
    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: TextFormField(
              initialValue: submission.awardedPoints.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                final newValue = int.tryParse(value);
                if (newValue != null &&
                    newValue >= 0 &&
                    newValue <= submission.maxPoints) {
                  setState(() {
                    submission.awardedPoints = newValue;
                    _hasUnsavedChanges = true;
                  });
                }
              },
            ),
          ),
          Text(
            ' / ${submission.maxPoints} p',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${submission.awardedPoints} / ${submission.maxPoints} pont',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildStatisticsPanel() {
    final theme = Theme.of(context);
    final stats = _statistics;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    // Wider panel to fit text properly
    final panelWidth = isMobile ? screenWidth * 0.75 : 380.0;

    // Always render so animation works
    return Positioned.fill(
      child: Stack(
        children: [
          // Background overlay with fade animation
          IgnorePointer(
            ignoring: !_showStatisticsPanel,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showStatisticsPanel ? 1 : 0,
              child: GestureDetector(
                onTap: () => setState(() => _showStatisticsPanel = false),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            right: _showStatisticsPanel ? 0 : -panelWidth,
            top: 0,
            bottom: 0,
            width: panelWidth,
            child: Material(
              elevation: 16,
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 40, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            color: theme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Statisztika',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showStatisticsPanel = false),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: theme.dividerColor.withOpacity(0.5),
                      height: 1,
                    ),
                    // Content
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          _buildStatCard(
                            'Helyes válaszok',
                            '${stats['correctCount']} / ${stats['totalQuestions']}',
                            Colors.green,
                            Icons.check_circle_outline,
                          ),
                          _buildStatCard(
                            'Részben helyes',
                            '${stats['partialCount']}',
                            Colors.amber,
                            Icons.warning_amber_rounded,
                          ),
                          _buildStatCard(
                            'Helytelen válaszok',
                            '${stats['incorrectCount']}',
                            Colors.red,
                            Icons.highlight_off_rounded,
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 32),
                          _buildStatCard(
                            'Eredmény',
                            '${(stats['percentage'] as double).toStringAsFixed(1)}%',
                            theme.primaryColor,
                            Icons.percent,
                            isLarge: true,
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: Text(
                                '${stats['totalAwardedPoints']} / ${stats['totalMaxPoints']} pont',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.9),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isLarge = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isLarge ? 32 : 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isLarge ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSettingsPanel(ThemeData theme, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 350,
      margin: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 120, left: 24, bottom: 120),
      decoration: isMobile
          ? null
          : BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, isMobile ? 60 : 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.tune, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Osztályzat Határok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Állítsd be a százalékos határokat az osztályzatokhoz (Minimum %).',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSliderForGrade(
                  theme: theme,
                  grade: 2,
                  value: _grade2Min,
                  color: Colors.red,
                  onChanged: (val) {
                    setState(() {
                      _grade2Min = val.toInt().clamp(0, 100);
                      // Ensure logical order
                      if (_grade2Min >= _grade3Min) {
                        _grade3Min = (_grade2Min + 1).clamp(0, 100);
                      }
                      if (_grade3Min >= _grade4Min) {
                        _grade4Min = (_grade3Min + 1).clamp(0, 100);
                      }
                      if (_grade4Min >= _grade5Min) {
                        _grade5Min = (_grade4Min + 1).clamp(0, 100);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                _buildSliderForGrade(
                  theme: theme,
                  grade: 3,
                  value: _grade3Min,
                  color: Colors.amber,
                  onChanged: (val) {
                    setState(() {
                      _grade3Min = val.toInt().clamp(0, 100);
                      if (_grade3Min <= _grade2Min) {
                        _grade2Min = (_grade3Min - 1).clamp(0, 100);
                      }
                      if (_grade3Min >= _grade4Min) {
                        _grade4Min = (_grade3Min + 1).clamp(0, 100);
                      }
                      if (_grade4Min >= _grade5Min) {
                        _grade5Min = (_grade4Min + 1).clamp(0, 100);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                _buildSliderForGrade(
                  theme: theme,
                  grade: 4,
                  value: _grade4Min,
                  color: Colors.lightGreen,
                  onChanged: (val) {
                    setState(() {
                      _grade4Min = val.toInt().clamp(0, 100);
                      if (_grade4Min <= _grade3Min) {
                        _grade3Min = (_grade4Min - 1).clamp(0, 100);
                      }
                      if (_grade3Min <= _grade2Min) {
                        _grade2Min = (_grade3Min - 1).clamp(0, 100);
                      }
                      if (_grade4Min >= _grade5Min) {
                        _grade5Min = (_grade4Min + 1).clamp(0, 100);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                _buildSliderForGrade(
                  theme: theme,
                  grade: 5,
                  value: _grade5Min,
                  color: Colors.green,
                  onChanged: (val) {
                    setState(() {
                      _grade5Min = val.toInt().clamp(0, 100);
                      if (_grade5Min <= _grade4Min) {
                        _grade4Min = (_grade5Min - 1).clamp(0, 100);
                      }
                      if (_grade4Min <= _grade3Min) {
                        _grade3Min = (_grade4Min - 1).clamp(0, 100);
                      }
                      if (_grade3Min <= _grade2Min) {
                        _grade2Min = (_grade3Min - 1).clamp(0, 100);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderForGrade({
    required ThemeData theme,
    required int grade,
    required int value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$grade-es (Minimum)',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '$value%',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color.withOpacity(0.5),
            inactiveTrackColor: theme.dividerColor,
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 4,
            valueIndicatorColor: color,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$value%',
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBottomBar() {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 500;
    final isMobile = screenWidth < 700;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: EdgeInsets.only(
        left: isNarrow ? 8 : 16,
        right: isNarrow ? 8 : 16,
        top: 8,
        bottom: bottomPadding + 8,
      ),
      child: Row(
        children: [
          // Back Button
          _buildBackButton(theme, isNarrow),
          SizedBox(width: isNarrow ? 4 : 8),

          // Menu Button (mobile only - opens drawer)
          if (isMobile) ...[
            _buildMenuButton(theme, isNarrow),
            SizedBox(width: isNarrow ? 4 : 8),
          ],

          Spacer(),

          // Stats Button (now on all screens)
          _buildStatsButton(theme, isNarrow),
          SizedBox(width: isNarrow ? 4 : 8),

          // Grade Bubble (compact on narrow screens)
          _buildCompactGradeBubble(theme, isNarrow),
          SizedBox(width: isNarrow ? 4 : 8),

          // Edit/Save Button
          _buildEditSaveButton(theme, isNarrow, isMobile),
        ],
      ),
    );
  }

  Widget _buildBackButton(ThemeData theme, bool isNarrow) {
    final size = isNarrow ? 40.0 : 48.0;
    return InkWell(
      onTap: () async {
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: isNarrow ? 20 : 24,
        ),
      ),
    );
  }

  Widget _buildMenuButton(ThemeData theme, bool isNarrow) {
    final size = isNarrow ? 36.0 : 44.0; // Same size as stats button
    return InkWell(
      onTap: () => _scaffoldKey.currentState?.openDrawer(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Icon(
          _isEditing ? Icons.tune : Icons.people,
          size: isNarrow ? 18 : 22,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildStatsButton(ThemeData theme, bool isNarrow) {
    final size = isNarrow ? 36.0 : 44.0;
    return InkWell(
      onTap: () => setState(() => _showStatisticsPanel = !_showStatisticsPanel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        child: Icon(
          Icons.bar_chart_rounded,
          size: isNarrow ? 18 : 22,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildFloatingStatsButton(ThemeData theme) {
    // Same style as edit button
    const size = 44.0;
    return InkWell(
      onTap: () => setState(() => _showStatisticsPanel = !_showStatisticsPanel),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Icon(
          Icons.bar_chart_rounded,
          size: 20,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCompactGradeBubble(ThemeData theme, bool isNarrow) {
    // Cheating logic for grade limits
    final isCheated = _cheatingStatus == 'confirmed';
    final minOffset = isCheated ? (1 - _calculatedGrade) : -1;
    final maxOffset = 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 6 : 12,
        vertical: isNarrow ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Points (hide on narrow)
          if (!isNarrow) ...[
            Text(
              '$_totalPoints/$_maxPoints',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            Container(
              height: 16,
              width: 1,
              color: theme.dividerColor,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
          // Grade adjustment buttons (when editing)
          if (_isEditing)
            InkWell(
              onTap: _manualGradeOffset > minOffset
                  ? () => setState(() {
                      _manualGradeOffset--;
                      _hasUnsavedChanges = true;
                    })
                  : null,
              child: Icon(
                Icons.remove_circle,
                size: isNarrow ? 16 : 20,
                color: _manualGradeOffset > minOffset
                    ? theme.primaryColor
                    : theme.disabledColor,
              ),
            ),
          // Grade number
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8),
            child: Text(
              '$_finalGrade',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: isNarrow ? 18 : 22,
                color: _cheatingStatus == 'confirmed'
                    ? Colors.red
                    : (_manualGradeOffset != 0
                          ? Colors.amber
                          : theme.primaryColor),
              ),
            ),
          ),
          // Grade up button (when editing)
          if (_isEditing)
            InkWell(
              onTap: _manualGradeOffset < maxOffset
                  ? () => setState(() {
                      _manualGradeOffset++;
                      _hasUnsavedChanges = true;
                    })
                  : null,
              child: Icon(
                Icons.add_circle,
                size: isNarrow ? 16 : 20,
                color: _manualGradeOffset < maxOffset
                    ? theme.primaryColor
                    : theme.disabledColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditSaveButton(ThemeData theme, bool isNarrow, bool isMobile) {
    // On narrow screens, just show icon in a container (properly centered)
    if (isNarrow || isMobile) {
      const size = 44.0; // Same size as floating stats button
      return InkWell(
        onTap: _isEditing
            ? _saveChanges
            : () => setState(() => _isEditing = true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _isEditing ? theme.primaryColor : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: _isEditing ? null : Border.all(color: theme.dividerColor),
          ),
          child: Icon(
            _isEditing ? Icons.save : Icons.edit,
            size: isNarrow ? 18 : 20,
            color: _isEditing ? Colors.white : theme.textTheme.bodyLarge?.color,
          ),
        ),
      );
    }

    // Desktop: Use full button with label
    if (_isEditing) {
      return ElevatedButton.icon(
        onPressed: _saveChanges,
        icon: const Icon(Icons.save, size: 18),
        label: const Text('Mentés'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Szerkesztés'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.cardColor,
          foregroundColor: theme.textTheme.bodyLarge?.color,
          side: BorderSide(color: theme.dividerColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildGradeBubble(ThemeData theme) {
    // Cheating Logic for Limits
    final isCheated = _cheatingStatus == 'confirmed';
    final minOffset = isCheated ? (1 - _calculatedGrade) : -1;
    final maxOffset = 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_totalPoints / $_maxPoints',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'PONT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          Container(
            height: 24,
            width: 1,
            color: theme.dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Row(
            children: [
              if (_isEditing)
                InkWell(
                  onTap: _manualGradeOffset > minOffset
                      ? () => setState(() {
                          _manualGradeOffset--;
                          _hasUnsavedChanges = true;
                        })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.remove_circle,
                      size: 20,
                      color: _manualGradeOffset > minOffset
                          ? theme.primaryColor
                          : theme.disabledColor,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '$_finalGrade',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: _cheatingStatus == 'confirmed'
                        ? Colors.red
                        : (_manualGradeOffset != 0
                              ? Colors.amber
                              : theme.primaryColor),
                  ),
                ),
              ),
              if (_isEditing)
                InkWell(
                  onTap: _manualGradeOffset < maxOffset
                      ? () => setState(() {
                          _manualGradeOffset++;
                          _hasUnsavedChanges = true;
                        })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.add_circle,
                      size: 20,
                      color: _manualGradeOffset < maxOffset
                          ? theme.primaryColor
                          : theme.disabledColor,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusAttributes(String status) {
    switch (status) {
      case 'confirmed':
        return {
          'color': Colors.red,
          'icon': Icons.lock_clock,
          'text': 'Letiltva',
        };
      case 'suspected':
        return {'color': Colors.amber, 'icon': Icons.block, 'text': 'Gyanús'};
      case 'none':
      default:
        return {
          'color': Colors.green,
          'icon': Icons.check_circle_outline,
          'text': 'Rendben',
        };
    }
  }
}
