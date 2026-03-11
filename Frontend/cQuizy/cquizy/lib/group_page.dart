// lib/group_page.dart

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter/services.dart'; // A vágólaphoz szükséges
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'test_taking_page.dart';
import 'utils/web_protections.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'admin_page.dart';
import 'create_quiz_dialog.dart';
import 'package:flutter/foundation.dart';

// --- MEOSZTOTT MODELL ---
class Group {
  final int? id;
  final String title;
  final String subtitle;
  final Color color;
  final bool hasNotification;
  final DateTime? testExpiryDate;
  final String? activeTestTitle;
  final String? activeTestDescription;
  final String? inviteCode;
  final String? inviteCodeFormatted;
  final String? rank; // ADMIN = teacher/admin
  final String ownerName;
  final String instructorFirstName;
  final String instructorLastName;
  final Map<String, dynamic>? activeQuizData;
  final List<Map<String, dynamic>> allActiveQuizzes;
  final bool anticheat; // Védelmi szint
  final bool kiosk; // Zárolt mód
  final int grade2Limit;
  final int grade3Limit;
  final int grade4Limit;
  final int grade5Limit;

  Group({
    this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    this.hasNotification = false,
    this.testExpiryDate,
    this.activeTestTitle,
    this.activeTestDescription,
    this.inviteCode,
    this.inviteCodeFormatted,
    this.rank,
    required this.ownerName,
    this.instructorFirstName = '',
    this.instructorLastName = '',
    this.activeQuizData,
    this.allActiveQuizzes = const [],
    this.anticheat = false, // Default: Nyitott (no protection)
    this.kiosk = false, // Default disabled
    this.grade2Limit = 40,
    this.grade3Limit = 55,
    this.grade4Limit = 70,
    this.grade5Limit = 85,
  });

  Group copyWith({
    String? title,
    String? subtitle,
    Color? color,
    bool? hasNotification,
    DateTime? testExpiryDate,
    String? activeTestTitle,
    String? activeTestDescription,
    String? ownerName,
    String? instructorFirstName,
    String? instructorLastName,
    Map<String, dynamic>? activeQuizData,
    List<Map<String, dynamic>>? allActiveQuizzes,
    int? grade2Limit,
    int? grade3Limit,
    int? grade4Limit,
    int? grade5Limit,
  }) {
    return Group(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      hasNotification: hasNotification ?? this.hasNotification,
      testExpiryDate: testExpiryDate ?? this.testExpiryDate,
      activeTestTitle: activeTestTitle ?? this.activeTestTitle,
      activeTestDescription:
          activeTestDescription ?? this.activeTestDescription,
      ownerName: ownerName ?? this.ownerName,
      instructorFirstName: instructorFirstName ?? this.instructorFirstName,
      instructorLastName: instructorLastName ?? this.instructorLastName,
      inviteCode: inviteCode,
      inviteCodeFormatted: inviteCodeFormatted,
      rank: rank,
      id: id,
      activeQuizData: activeQuizData ?? this.activeQuizData,
      allActiveQuizzes: allActiveQuizzes ?? this.allActiveQuizzes,
      anticheat: anticheat,
      kiosk: kiosk,
      grade2Limit: grade2Limit ?? this.grade2Limit,
      grade3Limit: grade3Limit ?? this.grade3Limit,
      grade4Limit: grade4Limit ?? this.grade4Limit,
      grade5Limit: grade5Limit ?? this.grade5Limit,
    );
  }

  // Dinamikus gradient generálás a téma alapján
  Gradient getGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(color);

    Color startColor; // Bal felső sarok
    Color endColor; // Jobb alsó sarok

    if (isDark) {
      // Sötét módban: jobb alsó világosabb -> bal felső sötétebb
      endColor = color; // Jobb alsó
      startColor = hsl
          .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
          .toColor(); // Bal felső (sötétebb)
    } else {
      // Világos módban: jobb alsó sötétebb -> bal felső világosabb
      endColor = color; // Jobb alsó
      startColor = hsl
          .withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0))
          .toColor(); // Bal felső (világosabb)
    }

    return LinearGradient(
      colors: [startColor, endColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Dinamikus szövegszín meghatározása a téma alapján
  Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }
}
// --- CSOPORT NÉZET WIDGET ---

class GroupPage extends StatefulWidget {
  final Group group;
  final Function(Group) onTestExpired;
  final ValueChanged<bool>? onMemberPanelToggle;
  final VoidCallback? onAdminTransferred;
  final VoidCallback? onGroupUpdated;
  final VoidCallback? onGroupLeft;

  const GroupPage({
    super.key,
    required this.group,
    required this.onTestExpired,
    this.onMemberPanelToggle,
    this.onAdminTransferred,
    this.onGroupUpdated,
    this.onGroupLeft,
  });

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMembersPanelVisible = false;
  // late List<Map<String, String>> _pastTests; // Removed mock data
  List<Map<String, dynamic>> _userResults = [];
  bool _isLoadingResults = false;
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;
  int? _expandedMemberId;

  // Customize Panel State
  bool _isCustomizePanelVisible = false;
  late TextEditingController _groupNameController;
  late Color _selectedColor;
  // Protection level: 0 = Nyitott, 1 = Védett, 2 = Zárolt
  int _protectionLevel = 1; // Default to Védett

  // Grading State
  int _grade2 = 40;
  int _grade3 = 55;
  int _grade4 = 70;
  int _grade5 = 85;

  // HSL Color State
  double _hue = 0.0;
  double _saturation = 0.7;
  double _lightness = 0.6;
  bool _showCustomColorPicker = false;

  // Invite Code State
  String? _currentInviteCode;
  bool _isRegeneratingCode = false;

  // Active Test Pagination State
  int _activeHeroIndex = 0;

  List<Map<String, dynamic>> _quizzes = [];
  bool _isLoadingQuizzes = false;

  @override
  void initState() {
    super.initState();
    // _pastTests = ...; // Removed mock data
    _fetchMembers();
    _fetchQuizzes();
    _fetchUserResults();

    // Init customize state
    _groupNameController = TextEditingController(text: widget.group.title);
    _selectedColor = widget.group.color;
    final hsl = HSLColor.fromColor(_selectedColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;

    // Init grading state
    _grade2 = widget.group.grade2Limit;
    _grade3 = widget.group.grade3Limit;
    _grade4 = widget.group.grade4Limit;
    _grade5 = widget.group.grade5Limit;

    // Initialize invite code
    _currentInviteCode =
        widget.group.inviteCodeFormatted ?? widget.group.inviteCode;

    // Initialize protection level from group settings
    // kiosk=true means Zárolt (2), anticheat=true means Védett (1), else Nyitott (0)
    if (widget.group.kiosk) {
      _protectionLevel = 2; // Zárolt
    } else if (widget.group.anticheat) {
      _protectionLevel = 1; // Védett
    } else {
      _protectionLevel = 0; // Nyitott
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    if (widget.group.id == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    setState(() => _isLoadingMembers = true);

    final apiService = ApiService();
    final membersData = await apiService.getGroupMembers(
      token,
      widget.group.id!,
    );

    setState(() {
      _members = membersData;
      _isLoadingMembers = false;
    });
  }

  Future<void> _fetchUserResults({bool silent = false}) async {
    if (widget.group.id == null) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    if (!silent) setState(() => _isLoadingResults = true);

    final apiService = ApiService();
    final results = await apiService.getUserResults(token, widget.group.id!);

    if (mounted) {
      setState(() {
        _userResults = results;
        if (!silent) _isLoadingResults = false;
      });
    }
  }

  @override
  void didUpdateWidget(GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh quizzes and results silently when group data updates
    _fetchQuizzes(silent: true);
    _fetchUserResults(silent: true);

    if (oldWidget.group.hasNotification &&
        !widget.group.hasNotification &&
        oldWidget.group.activeTestTitle != null) {
      // Mock logic removed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Stack(
            children: [
              _buildTestContent(),
              if (_isMembersPanelVisible || _isCustomizePanelVisible)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedMemberId = null;
                      _isMembersPanelVisible = false;
                      _isCustomizePanelVisible = false;
                    });
                    widget.onMemberPanelToggle?.call(false);
                  },
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              _buildMembersPanel(),
              _buildCustomizePanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: widget.group.getGradient(context),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 12 : 16,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Csoport neve
                  Text(
                    widget.group.title,
                    style: TextStyle(
                      color: widget.group.getTextColor(context),
                      fontSize: isMobile ? 22 : 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black38
                              : Colors.white38,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Oktató neve
                  Text(
                    'Oktató: ${widget.group.instructorLastName} ${widget.group.instructorFirstName}',
                    style: TextStyle(
                      color: widget.group
                          .getTextColor(context)
                          .withValues(alpha: 0.9),
                      fontSize: isMobile ? 13 : 18,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  // Gombok
                  if (isMobile)
                    // Mobil nézet: ikonok felirattal
                    Row(
                      children: [
                        if (widget.group.rank == 'ADMIN')
                          _buildHeaderButton(
                            context,
                            icon: Icons.settings,
                            label: 'Beállítások',
                            onPressed: () {
                              setState(() {
                                _isCustomizePanelVisible =
                                    !_isCustomizePanelVisible;
                                if (_isCustomizePanelVisible) {
                                  _isMembersPanelVisible = false;
                                }
                              });
                              widget.onMemberPanelToggle?.call(
                                _isCustomizePanelVisible ||
                                    _isMembersPanelVisible,
                              );
                            },
                          )
                        else
                          _buildHeaderButton(
                            context,
                            icon: Icons.exit_to_app,
                            label: 'Kilépés',
                            onPressed: () =>
                                _showLeaveGroupConfirmation(context),
                          ),
                        const SizedBox(width: 8),
                        _buildHeaderButton(
                          context,
                          icon: Icons.people_outline,
                          label: 'Tagok',
                          onPressed: () {
                            setState(() {
                              _isMembersPanelVisible = !_isMembersPanelVisible;
                              if (_isMembersPanelVisible) {
                                _isCustomizePanelVisible = false;
                              }
                            });
                            widget.onMemberPanelToggle?.call(
                              _isMembersPanelVisible ||
                                  _isCustomizePanelVisible,
                            );
                          },
                        ),
                      ],
                    )
                  else
                    // Desktop nézet: teljes gombok
                    Row(
                      children: [
                        if (widget.group.rank == 'ADMIN') ...[
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isCustomizePanelVisible =
                                    !_isCustomizePanelVisible;
                                if (_isCustomizePanelVisible) {
                                  _isMembersPanelVisible = false;
                                }
                              });
                              widget.onMemberPanelToggle?.call(
                                _isCustomizePanelVisible ||
                                    _isMembersPanelVisible,
                              );
                            },
                            icon: Icon(
                              Icons.settings,
                              color: widget.group.getTextColor(context),
                            ),
                            label: Text(
                              'Beállítások',
                              style: TextStyle(
                                color: widget.group.getTextColor(context),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: widget.group
                                    .getTextColor(context)
                                    .withValues(alpha: 0.7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showLeaveGroupConfirmation(context),
                            icon: Icon(
                              Icons.exit_to_app,
                              color: widget.group.getTextColor(context),
                            ),
                            label: Text(
                              'Csoport elhagyása',
                              style: TextStyle(
                                color: widget.group.getTextColor(context),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: widget.group
                                    .getTextColor(context)
                                    .withValues(alpha: 0.7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isMembersPanelVisible = !_isMembersPanelVisible;
                              if (_isMembersPanelVisible) {
                                _isCustomizePanelVisible = false;
                              }
                            });
                            widget.onMemberPanelToggle?.call(
                              _isMembersPanelVisible ||
                                  _isCustomizePanelVisible,
                            );
                          },
                          icon: Icon(
                            Icons.people_outline,
                            color: widget.group.getTextColor(context),
                          ),
                          label: Text(
                            'Tagok',
                            style: TextStyle(
                              color: widget.group.getTextColor(context),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: widget.group
                                  .getTextColor(context)
                                  .withValues(alpha: 0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.group.getTextColor(context).withValues(alpha: 0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: widget.group.getTextColor(context), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: widget.group.getTextColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroActiveTestCard(List<Map<String, dynamic>> quizzes) {
    if (quizzes.isEmpty) return const SizedBox.shrink();
    if (_activeHeroIndex >= quizzes.length) _activeHeroIndex = 0;

    final quiz = quizzes[_activeHeroIndex];
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Parse dates
    final end = DateTime.tryParse(quiz['date_end'] ?? '')?.toLocal() ?? now;
    final start = DateTime.tryParse(quiz['date_start'] ?? '')?.toLocal() ?? now;

    final isAdmin = widget.group.rank == 'ADMIN';

    void openAdmin() {
      if (isAdmin) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminPage(
              quiz: quiz,
              groupId: widget.group.id!,
              groupName: widget.group.title,
              grade2Limit: widget.group.grade2Limit,
              grade3Limit: widget.group.grade3Limit,
              grade4Limit: widget.group.grade4Limit,
              grade5Limit: widget.group.grade5Limit,
            ),
          ),
        );
      }
    }

    return GestureDetector(
      onLongPress: openAdmin,
      onSecondaryTap: openAdmin,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'JELENLEG AKTÍV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (quizzes.length > 1)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        color: theme.primaryColor,
                        onPressed: _activeHeroIndex > 0
                            ? () => setState(() => _activeHeroIndex--)
                            : null,
                      ),
                      Text(
                        '${_activeHeroIndex + 1}/${quizzes.length}',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        color: theme.primaryColor,
                        onPressed: _activeHeroIndex < quizzes.length - 1
                            ? () => setState(() => _activeHeroIndex++)
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              quiz['project_name'] ?? 'Névtelen teszt',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.timer, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: CountdownTimerWidget(
                    expiryDate: end,
                    isBig: true,
                    onExpired: _fetchQuizzes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy. MM. dd. HH:mm').format(start),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('yyyy. MM. dd. HH:mm').format(end),
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SpectacularProgressBar(start: start, end: end),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (isAdmin) {
                    openAdmin();
                  } else {
                    _showStartTestConfirmation(context, quiz);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isAdmin ? 'Admin felület megnyitása' : 'Teszt kitöltése',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestContent() {
    if ((_isLoadingQuizzes && _quizzes.isEmpty) ||
        (_isLoadingResults && _userResults.isEmpty)) {
      return Center(
        child: LoadingAnimationWidget.newtonCradle(
          color: Theme.of(context).primaryColor,
          size: 80,
        ),
      );
    }

    final now = DateTime.now();
    final active = <Map<String, dynamic>>[];
    final future = <Map<String, dynamic>>[];
    final past = <Map<String, dynamic>>[];

    for (var quiz in _quizzes) {
      final start = DateTime.tryParse(quiz['date_start'] ?? '');
      final end = DateTime.tryParse(quiz['date_end'] ?? '');

      if (start != null && end != null) {
        if (!now.isBefore(start) && !now.isAfter(end)) {
          active.add(quiz);
        } else if (now.isBefore(start)) {
          future.add(quiz);
        } else {
          past.add(quiz);
        }
      }
    }

    // Sort lists
    // Active: closest to ending first
    active.sort((a, b) {
      final endA = DateTime.tryParse(a['date_end'] ?? '') ?? DateTime(0);
      final endB = DateTime.tryParse(b['date_end'] ?? '') ?? DateTime(0);
      return endA.compareTo(endB);
    });

    // Future: closest to starting first
    future.sort((a, b) {
      final startA = DateTime.tryParse(a['date_start'] ?? '') ?? DateTime(0);
      final startB = DateTime.tryParse(b['date_start'] ?? '') ?? DateTime(0);
      return startA.compareTo(startB);
    });

    // Past: most recently ended first
    past.sort((a, b) {
      final endA = DateTime.tryParse(a['date_end'] ?? '') ?? DateTime(0);
      final endB = DateTime.tryParse(b['date_end'] ?? '') ?? DateTime(0);
      return endB.compareTo(endA);
    });

    // Past: most recently ended first
    past.sort((a, b) {
      final endA = DateTime.tryParse(a['date_end'] ?? '') ?? DateTime(0);
      final endB = DateTime.tryParse(b['date_end'] ?? '') ?? DateTime(0);
      return endB.compareTo(endA);
    });

    if (active.isEmpty &&
        future.isEmpty &&
        past.isEmpty &&
        _userResults.isEmpty) {
      return Center(
        child: Text(
          'Nincsenek tesztek ebben a csoportban.',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        if (active.isNotEmpty) ...[
          _buildHeroActiveTestCard(active),
          const SizedBox(height: 24),
        ],
        if (future.isNotEmpty) ...[
          const HeaderWithDivider(title: 'Jövőbeli tesztek'),
          const SizedBox(height: 16),
          ...future.map(
            (q) => _buildTestCard(
              quiz: q,
              title: q['project_name'] ?? 'Névtelen',
              detail: 'Kezdődik: ${_formatDate(q['date_start'])}',
              isGrade: false,
              onTap: () => _showQuizOptions(q),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (past.isNotEmpty) ...[
          const HeaderWithDivider(title: 'Múltbeli tesztek'),
          const SizedBox(height: 16),
          ...past.map(
            (q) => _buildTestCard(
              quiz: q,
              title: q['project_name'] ?? 'Névtelen',
              detail: 'Lezárult: ${_formatDate(q['date_end'])}',
              isGrade: false,
              onTap: () {
                if (widget.group.rank == 'ADMIN') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminPage(
                        quiz: q,
                        groupId: widget.group.id!,
                        groupName: widget.group.title,
                        grade2Limit: widget.group.grade2Limit,
                        grade3Limit: widget.group.grade3Limit,
                        grade4Limit: widget.group.grade4Limit,
                        grade5Limit: widget.group.grade5Limit,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildTestCard({
    required Map<String, dynamic> quiz,
    required String title,
    required String detail,
    String? subDetail,
    required bool isGrade,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showQuizOptions(quiz),
      onSecondaryTap: () => _showQuizOptions(quiz),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                  if (subDetail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subDetail,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              detail,
              style: TextStyle(
                color: isGrade
                    ? theme.textTheme.bodyLarge?.color
                    : theme.textTheme.bodyMedium?.color,
                fontSize: isGrade ? 22 : 14,
                fontWeight: isGrade ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchQuizzes({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingQuizzes = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final apiService = ApiService();
    if (userProvider.token == null || widget.group.id == null) {
      if (mounted && !silent) setState(() => _isLoadingQuizzes = false);
      return;
    }

    final quizzes = await apiService.getGroupQuizzes(
      userProvider.token!,
      widget.group.id!,
    );

    if (mounted) {
      setState(() {
        _quizzes = quizzes;
        if (!silent) _isLoadingQuizzes = false;
      });
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final date = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy. MM. dd. HH:mm').format(date);
    } catch (e) {
      return iso;
    }
  }

  void _showEditQuiz(Map<String, dynamic> quiz) async {
    await showDialog(
      context: context,
      builder: (context) =>
          CreateQuizDialog(groupId: widget.group.id!, existingQuiz: quiz),
    );
    _fetchQuizzes();
  }

  Future<void> _startQuizNow(Map<String, dynamic> quiz) async {
    final theme = Theme.of(context);
    final quizId = quiz['id'];

    // Default: +45 mins from now
    DateTime endDate = DateTime.now().add(const Duration(minutes: 45));
    int selectedMode = 0; // 0: Duration, 1: Date

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDuration = selectedMode == 0;
          return Dialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teszt indítása',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Időtartam'),
                          selected: isDuration,
                          onSelected: (v) => setState(() => selectedMode = 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Dátum'),
                          selected: !isDuration,
                          onSelected: (v) => setState(() => selectedMode = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isDuration) ...[
                    DropdownButtonFormField<int>(
                      initialValue: 45,
                      decoration: const InputDecoration(
                        labelText: 'Időtartam (perc)',
                      ),
                      items: [15, 30, 45, 60, 90]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text('$e perc'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          endDate = DateTime.now().add(Duration(minutes: v));
                        }
                      },
                    ),
                  ] else ...[
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_formatDate(endDate.toIso8601String())),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                          initialDate: endDate,
                        );
                        if (picked != null) {
                          if (!mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endDate),
                          );
                          if (time != null) {
                            setState(
                              () => endDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Mégse'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, {'endDate': endDate}),
                        child: const Text('Indítás'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null && result['endDate'] != null && mounted) {
      if (quizId == null || quizId is! int) return;

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final apiService = ApiService();

      try {
        await apiService.updateQuiz(
          userProvider.token!,
          quizId,
          DateTime.now().toUtc().toIso8601String(),
          (result['endDate'] as DateTime).toUtc().toIso8601String(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teszt indítása sikeres!')),
          );
          _fetchQuizzes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hiba: $e')));
        }
      }
    }
  }

  void _showStartTestConfirmation(
    BuildContext context,
    Map<String, dynamic> quiz,
  ) {
    if (kIsWeb && widget.group.kiosk) {
      _showWebKioskRestrictionDialog(context);
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with orange gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF57C00), // Orange Dark
                            Color(0xFFFF9800), // Orange
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Teszt indítása',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            'A teszt kitöltése alatt nem lehet kilépni a felületből. Biztosan elindítod?',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Mégse',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  WebProtections.enterFullScreen(); // Request fullscreen on web gesture
                                  Navigator.pop(context); // Close dialog

                                  // Prepare quiz object with group back-reference
                                  final quizData = Map<String, dynamic>.from(
                                    quiz,
                                  );
                                  quizData['group_obj'] = widget.group;

                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TestTakingPage(
                                        quiz: quizData,
                                        groupName: widget.group.title,
                                        anticheat: widget.group.anticheat,
                                        kiosk: widget.group.kiosk,
                                      ),
                                    ),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF57C00),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Indítás',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWebKioskRestrictionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.desktop_windows_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Csak alkalmazásban elérhető'),
          ],
        ),
        content: const Text(
          'Ez a teszt Zárolt védelmi szinttel (Kiosk módban) lett létrehozva. A webes böngésző nem támogatja ezt a szintű biztonságot.\n\nKérjük, nyisd meg az alkalmazást (Windows, Android vagy iOS) a teszt kitöltéséhez!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
  }

  void _showQuizOptions(Map<String, dynamic> quiz) {
    if (widget.group.rank != 'ADMIN') return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Color(0xFF009688)], // Green to Teal
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Teszt kezelése',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      quiz['project_name'] ?? 'Névtelen teszt',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildOptionButton(
                          label: 'Szerkesztés',
                          icon: Icons.edit_calendar_rounded,
                          color: const Color(0xFF5D3A44),
                          iconColor: const Color(0xFFFF5252),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showEditQuiz(quiz);
                          },
                        ),
                        // No logic to separate buttons, they touch
                        _buildOptionButton(
                          label: 'Indítás',
                          icon: Icons.play_arrow_rounded,
                          color: const Color(0xFF2E4A45),
                          iconColor: const Color(0xFF4DB6AC),
                          borderRadius: BorderRadius.zero,
                          onTap: () {
                            Navigator.pop(context);
                            _startQuizNow(quiz);
                          },
                        ),
                        _buildOptionButton(
                          label: 'Törlés',
                          icon: Icons.delete_rounded,
                          color: const Color(0xFF4A2E2E),
                          iconColor: const Color(0xFFE57373),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showDeleteQuizConfirmation(
                              context,
                              quiz['project_name'] ?? '',
                              quiz['id'],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                      child: const Text('Mégse'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
  }) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            height: 100,
            decoration: BoxDecoration(borderRadius: borderRadius),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String userName,
    int userId,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Color(0xFFFF5252)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_remove_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Tag eltávolítása',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hPadding = constraints.maxWidth < 400
                            ? 20.0
                            : 32.0;

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Biztosan el akarod távolítani $userName-t a csoportból?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Actions
                              Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _removeMember(userId);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.red.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: const Text(
                                      'Eltávolítás',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeMember(int userId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null || widget.group.id == null) return;

    setState(() => _isLoadingMembers = true);

    final apiService = ApiService();
    try {
      final success = await apiService.removeMember(
        token,
        widget.group.id!,
        userId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tag sikeresen eltávolítva'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchMembers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hiba a tag eltávolítása során'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _showDeleteQuizConfirmation(
    BuildContext context,
    String quizName,
    int quizId,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Color(0xFFFF5252)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Teszt eltávolítása',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hPadding = constraints.maxWidth < 400
                            ? 20.0
                            : 32.0;

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Biztosan el akarod távolítani a(z) "$quizName" tesztet?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Actions
                              Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteQuiz(quizId);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.red.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: const Text(
                                      'Törlés',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteQuiz(int quizId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    setState(() => _isLoadingQuizzes = true);

    final apiService = ApiService();
    try {
      final success = await apiService.deleteQuiz(token, quizId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teszt sikeresen törölve'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchQuizzes();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hiba a teszt törlése során'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuizzes = false);
      }
    }
  }

  void _showAdminTransferConfirmation(
    BuildContext context,
    String userName,
    int userId,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Color(0xFFFF9800)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Admin jog átadása',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hPadding = constraints.maxWidth < 400
                            ? 20.0
                            : 32.0;

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Biztosan átadod az admin jogot $userName-nak? Ezzel elveszíted a csoport feletti adminisztrátori jogodat.',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Actions
                              Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _transferAdmin(userId);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.orange.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: const Text(
                                      'Átadás',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _transferAdmin(int userId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null || widget.group.id == null) return;

    final apiService = ApiService();
    final success = await apiService.transferAdmin(
      token,
      widget.group.id!,
      userId,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin jog sikeresen átadva'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAdminTransferred?.call();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba az admin jog átadásakor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteGroupDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isLoading = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.red, Color(0xFFFF5252)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Csoport Törlése',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final hPadding = constraints.maxWidth < 400
                                ? 20.0
                                : 32.0;

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: hPadding,
                                vertical: 24,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Biztosan törölni szeretnéd a "${widget.group.title}" csoportot?',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Ez a művelet nem vonható vissza! A csoport és minden tagsága törlésre kerül.',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Jelszó megerősítés',
                                      prefixIcon: Icon(
                                        Icons.lock_rounded,
                                        color: theme.primaryColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: theme.primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Actions
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      TextButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(
                                          'Mégse',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.6),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () async {
                                                if (passwordController
                                                    .text
                                                    .isEmpty) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Kérlek add meg a jelszavadat!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                  return;
                                                }

                                                setDialogState(
                                                  () => isLoading = true,
                                                );

                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    );
                                                final navigator = Navigator.of(
                                                  context,
                                                );

                                                final success =
                                                    await _deleteGroup(
                                                      passwordController.text,
                                                    );

                                                if (!context.mounted) return;
                                                navigator.pop();

                                                if (success) {
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Csoport sikeresen törölve',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                  widget.onGroupLeft?.call();
                                                } else {
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Hiba a csoport törlésekor. Ellenőrizd a jelszót!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 4,
                                          shadowColor: Colors.red.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Törlés',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool> _deleteGroup(String password) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null || widget.group.id == null) return false;

    final apiService = ApiService();
    return await apiService.deleteGroup(token, widget.group.id!, password);
  }

  void _showLeaveGroupConfirmation(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Color(0xFFFF9800)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.exit_to_app_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Csoport elhagyása',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hPadding = constraints.maxWidth < 400
                            ? 20.0
                            : 32.0;

                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Biztosan elhagyod a "${widget.group.title}" csoportot?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Actions
                              Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _leaveGroup();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.orange.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    child: const Text(
                                      'Elhagyás',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null || widget.group.id == null) return;

    final apiService = ApiService();
    final success = await apiService.leaveGroup(token, widget.group.id!);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sikeresen elhagytad a "${widget.group.title}" csoportot',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onGroupLeft?.call();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba a csoport elhagyásakor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _regenerateInviteCode() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null || widget.group.id == null) return;

    setState(() => _isRegeneratingCode = true);

    final apiService = ApiService();
    final result = await apiService.regenerateInviteCode(
      token,
      widget.group.id!,
    );

    if (!mounted) return;

    setState(() => _isRegeneratingCode = false);

    if (result != null) {
      setState(() {
        _currentInviteCode =
            result['invite_code_formatted'] ?? result['invite_code'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Új meghívókód sikeresen generálva!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onGroupUpdated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiba az új meghívókód generálásakor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveGroupChanges() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;

    if (token == null || widget.group.id == null) return;

    final colorHex = _selectedColor
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();

    final success = await ApiService().updateGroup(
      token,
      widget.group.id!,
      name: _groupNameController.text,
      color: '#$colorHex',
      anticheat: _protectionLevel >= 1, // Védett or Zárolt
      kiosk: _protectionLevel >= 2, // Only Zárolt
      grade2Limit: _grade2,
      grade3Limit: _grade3,
      grade4Limit: _grade4,
      grade5Limit: _grade5,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Csoport beállítások frissítve'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isCustomizePanelVisible = false);
      widget.onMemberPanelToggle?.call(false);
      widget.onGroupUpdated?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiba a frissítés során'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCustomizePanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth > 500) ? 320.0 : screenWidth * 0.85;
    final theme = Theme.of(context);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: -10,
      bottom: 0,
      right: _isCustomizePanelVisible ? 0 : -panelWidth,
      width: panelWidth,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.5 : 0.1,
              ),
              blurRadius: 15,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.settings, color: theme.iconTheme.color, size: 24),
                  Text(
                    'Beállítások',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      setState(() {
                        _isCustomizePanelVisible = false;
                      });
                      widget.onMemberPanelToggle?.call(false);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionLabel('CSOPORT NEVE', theme),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _groupNameController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: _buildInputDecoration(
                      theme,
                      'pl. Matematika 9.A',
                      Icons.groups_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'A csoport neve kötelező';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionLabel('CSOPORT SZÍNE', theme),
                  const SizedBox(height: 16),
                  _buildColorPicker(theme),
                  const SizedBox(height: 24),
                  _buildSectionLabel('BEÁLLÍTÁSOK', theme),
                  const SizedBox(height: 16),
                  _buildProtectionSlider(theme),
                  const SizedBox(height: 24),
                  _buildGradingSection(theme),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveGroupChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Mentés'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Danger Zone: Delete Group
                  _buildSectionLabel('VESZÉLYES ZÓNA', theme),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteGroupDialog(context),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Csoport Törlése'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    ThemeData theme,
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: theme.iconTheme.color?.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showCustomColorPicker = !_showCustomColorPicker),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showCustomColorPicker
                    ? theme.primaryColor
                    : theme.dividerColor,
                width: _showCustomColorPicker ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _showCustomColorPicker
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 12),
                Text(
                  'Színkezelő',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.dividerColor, width: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showCustomColorPicker) ...[
          const SizedBox(height: 16),
          _buildHSLSliders(theme),
        ],
      ],
    );
  }

  Widget _buildHSLSliders(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColorSlider(
            theme: theme,
            label: 'Árnyalat',
            value: _hue,
            max: 360,
            divisions: 72,
            gradientColors: [
              const Color(0xFFFF0000),
              const Color(0xFFFFFF00),
              const Color(0xFF00FF00),
              const Color(0xFF00FFFF),
              const Color(0xFF0000FF),
              const Color(0xFFFF00FF),
              const Color(0xFFFF0000),
            ],
            onChanged: (val) {
              setState(() {
                _hue = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildColorSlider(
            theme: theme,
            label: 'Telítettség',
            value: _saturation,
            max: 1,
            divisions: 100,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, 0, _lightness).toColor(),
              HSLColor.fromAHSL(1.0, _hue, 1, _lightness).toColor(),
            ],
            onChanged: (val) {
              setState(() {
                _saturation = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
          const SizedBox(height: 16),
          _buildColorSlider(
            theme: theme,
            label: 'Világosság',
            value: _lightness,
            max: 1,
            divisions: 100,
            gradientColors: [
              const Color(0xFF000000),
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.5).toColor(),
              const Color(0xFFFFFFFF),
            ],
            onChanged: (val) {
              setState(() {
                _lightness = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorSlider({
    required ThemeData theme,
    required String label,
    required double value,
    required double max,
    required int divisions,
    required List<Color> gradientColors,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 32,
            ),
            child: Slider(
              value: value,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProtectionSlider(ThemeData theme) {
    final labels = ['Nyitott', 'Védett', 'Zárolt'];
    final icons = [
      Icons.lock_open_rounded,
      Icons.shield_rounded,
      Icons.lock_rounded,
    ];
    final colors = [Colors.green, Colors.orange, Colors.red];
    final descriptions = [
      'Nincs korlátozás. A tanulók szabadon használhatnak más alkalmazásokat.',
      'A rendszer figyeli a diákot, és jelzi a gyanús tevékenységeket.',
      'A diák eszköze teljesen lezár, és nem lehet más alkalmazásokat használni amíg be nem küldi a dolgozatot.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final isSelected = _protectionLevel == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _protectionLevel = index),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors[index].withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colors[index]
                                : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icons[index],
                          color: isSelected
                              ? colors[index]
                              : theme.iconTheme.color?.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: isSelected
                              ? colors[index]
                              : theme.textTheme.bodyMedium?.color?.withValues(
                                  alpha: 0.6,
                                ),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors[_protectionLevel],
              inactiveTrackColor: theme.dividerColor,
              thumbColor: colors[_protectionLevel],
              overlayColor: colors[_protectionLevel].withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _protectionLevel.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (value) =>
                  setState(() => _protectionLevel = value.toInt()),
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors[_protectionLevel].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colors[_protectionLevel],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    descriptions[_protectionLevel],
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grade_outlined, color: theme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Értékelési rendszer',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Állítsd be a százalékos határokat az osztályzatokhoz (Minimum %).',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          _buildSliderForGrade(
            theme: theme,
            grade: 2,
            value: _grade2,
            color: Colors.redAccent,
            onChanged: (val) {
              setState(() {
                _grade2 = val.round().clamp(0, 100);
                if (_grade2 >= _grade3) _grade3 = (_grade2 + 1).clamp(0, 100);
                if (_grade3 >= _grade4) _grade4 = (_grade3 + 1).clamp(0, 100);
                if (_grade4 >= _grade5) _grade5 = (_grade4 + 1).clamp(0, 100);
              });
            },
          ),
          _buildSliderForGrade(
            theme: theme,
            grade: 3,
            value: _grade3,
            color: Colors.orangeAccent,
            onChanged: (val) {
              setState(() {
                _grade3 = val.round().clamp(0, 100);
                if (_grade3 <= _grade2) _grade2 = (_grade3 - 1).clamp(0, 100);
                if (_grade3 >= _grade4) _grade4 = (_grade3 + 1).clamp(0, 100);
                if (_grade4 >= _grade5) _grade5 = (_grade4 + 1).clamp(0, 100);
              });
            },
          ),
          _buildSliderForGrade(
            theme: theme,
            grade: 4,
            value: _grade4,
            color: Colors.lightGreen,
            onChanged: (val) {
              setState(() {
                _grade4 = val.round().clamp(0, 100);
                if (_grade4 <= _grade3) _grade3 = (_grade4 - 1).clamp(0, 100);
                if (_grade3 <= _grade2) _grade2 = (_grade3 - 1).clamp(0, 100);
                if (_grade4 >= _grade5) _grade5 = (_grade4 + 1).clamp(0, 100);
              });
            },
          ),
          _buildSliderForGrade(
            theme: theme,
            grade: 5,
            value: _grade5,
            color: Colors.green,
            onChanged: (val) {
              setState(() {
                _grade5 = val.round().clamp(0, 100);
                if (_grade5 <= _grade4) _grade4 = (_grade5 - 1).clamp(0, 100);
                if (_grade4 <= _grade3) _grade3 = (_grade4 - 1).clamp(0, 100);
                if (_grade3 <= _grade2) _grade2 = (_grade3 - 1).clamp(0, 100);
              });
            },
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
                color: color.withValues(alpha: 0.2),
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
            activeTrackColor: color.withValues(alpha: 0.5),
            inactiveTrackColor: theme.dividerColor,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
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

  Widget _buildMembersPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth > 500) ? 320.0 : screenWidth * 0.85;
    final theme = Theme.of(context);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: -10,
      bottom: 0,
      right: _isMembersPanelVisible ? 0 : -panelWidth,
      width: panelWidth,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.5 : 0.1,
              ),
              blurRadius: 15,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.group, color: theme.iconTheme.color, size: 24),
                  Text(
                    'Csoport Tagjai (${_members.length})',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    onPressed: () {
                      setState(() {
                        _expandedMemberId = null;
                        _isMembersPanelVisible = false;
                      });
                      widget.onMemberPanelToggle?.call(false);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            if (widget.group.rank == 'ADMIN') _buildInviteCodeCard(),
            Expanded(
              child: _isLoadingMembers
                  ? Center(
                      child: LoadingAnimationWidget.newtonCradle(
                        color: theme.primaryColor,
                        size: 200,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      children: [
                        // Admins (rank == 'ADMIN')
                        ..._members
                            .where((m) => m['rank'] == 'ADMIN')
                            .map((m) => _buildMemberTile(m, isAdmin: true))
                            .toList(),
                        if (_members.any((m) => m['rank'] != 'ADMIN')) ...[
                          _buildSectionHeader(
                            'TAGOK (${_members.where((m) => m['rank'] != 'ADMIN').length})',
                          ),
                          Divider(color: theme.dividerColor, height: 1),
                        ],
                        // Regular members
                        ..._members
                            .where((m) => m['rank'] != 'ADMIN')
                            .map((m) => _buildMemberTile(m, isAdmin: false))
                            .toList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, {bool isAdmin = false}) {
    final theme = Theme.of(context);
    final user = member['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as int?;
    final nickname = user?['nickname'] as String? ?? '';
    final firstName = user?['first_name'] as String? ?? '';
    final lastName = user?['last_name'] as String? ?? '';
    final username = user?['username'] as String? ?? 'Felhasználó';
    final pfpUrl = user?['pfp_url'] as String?;

    final displayName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$lastName $firstName'.trim()
        : (nickname.isNotEmpty ? nickname : username);

    final currentUser = Provider.of<UserProvider>(context, listen: false).user;
    final isMe = currentUser?.id == userId;
    final amIAdmin = widget.group.rank == 'ADMIN';
    final canManage = amIAdmin && !isMe && !isAdmin;

    final isExpanded = _expandedMemberId == userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isExpanded ? theme.cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isExpanded ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main tile - always visible
          ListTile(
            onTap: canManage && userId != null
                ? () {
                    setState(() {
                      _expandedMemberId = isExpanded ? null : userId;
                    });
                  }
                : null,
            leading: CircleAvatar(
              backgroundColor: isAdmin
                  ? const Color(0xFFed2f5b)
                  : theme.primaryColor,
              backgroundImage: pfpUrl != null && pfpUrl.isNotEmpty
                  ? NetworkImage(pfpUrl)
                  : null,
              child: pfpUrl == null || pfpUrl.isEmpty
                  ? Icon(
                      isAdmin ? Icons.star : Icons.person,
                      color: Colors.white,
                    )
                  : null,
            ),
            title: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              isAdmin ? 'Admin' : 'Tag',
              style: TextStyle(
                color: isAdmin
                    ? const Color(0xFFED2F5B)
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
            trailing: isAdmin
                ? const Icon(Icons.workspace_premium, color: Color(0xFFed2f5b))
                : (canManage
                      ? AnimatedRotation(
                          turns: isExpanded ? 0.25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 24,
                            color: theme.iconTheme.color?.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        )
                      : null),
          ),
          // Action buttons - animated expand/collapse
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.admin_panel_settings,
                            label: 'Admin átadása',
                            color: Colors.orange,
                            onTap: () {
                              setState(() => _expandedMemberId = null);
                              if (userId != null) {
                                _showAdminTransferConfirmation(
                                  context,
                                  displayName,
                                  userId,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.person_remove,
                            label: 'Kidobás',
                            color: Colors.red,
                            onTap: () {
                              setState(() => _expandedMemberId = null);
                              if (userId != null) {
                                _showDeleteConfirmation(
                                  context,
                                  displayName,
                                  userId,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    final inviteCode = _currentInviteCode ?? 'N/A';
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEGHÍVÓKÓD',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                inviteCode,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isRegeneratingCode
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: LoadingAnimationWidget.newtonCradle(
                        color: theme.primaryColor,
                        size: 24,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: theme.iconTheme.color?.withValues(alpha: 0.7),
                      ),
                      tooltip: 'Új kód generálása',
                      onPressed: _regenerateInviteCode,
                    ),
              IconButton(
                icon: Icon(
                  Icons.copy_outlined,
                  color: theme.iconTheme.color?.withValues(alpha: 0.7),
                ),
                tooltip: 'Kód másolása',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meghívókód a vágólapra másolva!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- MEOSZTOTT WIDGETEK ---

class CountdownTimerWidget extends StatefulWidget {
  final DateTime expiryDate;
  final VoidCallback? onExpired;
  final bool isBig;

  const CountdownTimerWidget({
    super.key,
    required this.expiryDate,
    this.onExpired,
    this.isBig = false,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _countdownTimer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    if (!_remainingTime.isNegative) {
      _startCountdownTimer();
    }
  }

  void _updateRemainingTime() {
    if (mounted) {
      setState(() {
        _remainingTime = widget.expiryDate.difference(DateTime.now());
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();

      if (_remainingTime.isNegative) {
        _countdownTimer?.cancel();
        widget.onExpired?.call();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpired = _remainingTime.isNegative;

    if (isExpired) {
      return const SizedBox.shrink();
    }

    if (_remainingTime.inHours >= 12) {
      final formattedDate = DateFormat(
        'yyyy. MMM d. HH:mm',
      ).format(widget.expiryDate);
      return Text(
        formattedDate,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.isBig ? 16 : 14,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: widget.isBig ? 20 : 16,
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_remainingTime),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: widget.isBig ? 18 : 14,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _SpectacularProgressBar extends StatefulWidget {
  final DateTime start;
  final DateTime end;

  const _SpectacularProgressBar({required this.start, required this.end});

  @override
  State<_SpectacularProgressBar> createState() =>
      _SpectacularProgressBarState();
}

class _SpectacularProgressBarState extends State<_SpectacularProgressBar>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateProgress(),
    );
  }

  void _updateProgress() {
    final now = DateTime.now();
    final total = widget.end.difference(widget.start).inSeconds;
    final elapsed = now.difference(widget.start).inSeconds;

    double p = 0.0;
    if (total > 0) {
      p = (elapsed / total).clamp(0.0, 1.0);
    } else {
      p = 1.0;
    }

    if (mounted && p != _progress) {
      setState(() {
        _progress = p;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Calculate remaining percentage for the bar width (1.0 - progress)
    final barValue = (1.0 - _progress);

    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 1000),
            widthFactor: barValue,
            curve: Curves.linear,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.7),
                    theme.primaryColor,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderWithDivider extends StatelessWidget {
  final String title;
  const HeaderWithDivider({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: theme.textTheme.titleMedium?.color?.withValues(alpha: 0.8),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: theme.dividerColor),
      ],
    );
  }
}
