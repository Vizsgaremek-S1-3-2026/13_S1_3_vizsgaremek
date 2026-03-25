import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'group_page.dart';
import 'settings_page.dart';
import 'test_taking_page.dart';
import 'utils/web_protections.dart';

import 'create_group_page.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'projects_page.dart';
import 'create_project_dialog.dart';
import 'create_quiz_dialog.dart';
import 'theme.dart';
import 'admin_page.dart';
import 'package:flutter/foundation.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'student_tests_page.dart';
import 'statistics_page.dart';

const double kDesktopBreakpoint = 900.0;

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class ActiveTestItem {
  final Group group;
  final Map<String, dynamic> quiz;

  ActiveTestItem({required this.group, required this.quiz});

  String get title => quiz['project_name'] ?? 'Névtelen teszt';

  DateTime get expiryDate {
    return DateTime.tryParse(quiz['date_end'] ?? '')?.toLocal() ??
        DateTime.now();
  }
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Group> _myGroups = [];
  List<Group> _otherGroups = [];
  List<ActiveTestItem> _activeTests = []; // State for active tests sidebar

  Group? _selectedGroup;
  bool _isLoading = true;

  // New GlobalKeys for Tutorial
  final GlobalKey _tutorialButtonKey = GlobalKey();
  final GlobalKey _createGroupButtonKey = GlobalKey();
  final GlobalKey _speedDialKey = GlobalKey();
  final GlobalKey _sideNavKey = GlobalKey();
  final GlobalKey _projectsNavKey = GlobalKey();
  final GlobalKey _createProjectButtonKey = GlobalKey();

  bool _isTutorialButtonVisible = true;
  bool _isBottomBarVisible = true;
  bool _isMemberPanelOpen = false;
  bool _isSpeedDialOpen = false;
  bool _showProjects = false;
  bool _showStudentTests = false;
  bool _showStatistics = false;
  bool _isInProjectTutorial = false; // Flag for project creation tutorial
  int _projectsRefreshKey = 0;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    // Refresh every 30 seconds to catch starting tests
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchGroups();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<ActiveTestItem> _getActiveTests() {
    final allGroups = [..._myGroups, ..._otherGroups];
    final List<ActiveTestItem> items = [];

    for (var group in allGroups) {
      if (group.allActiveQuizzes.isNotEmpty) {
        for (var quiz in group.allActiveQuizzes) {
          items.add(ActiveTestItem(group: group, quiz: quiz));
        }
      }
    }
    return items;
  }

  void _initializeGroups() {
    _myGroups = [];
    _otherGroups = [];
    _activeTests = [];
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final apiService = ApiService();
    List<dynamic> groupsData;
    try {
      groupsData = await apiService.getUserGroups(token);
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final Map<int, String> groupAdminNames = {};
    final Map<int, String> groupAdminFirstNames = {};
    final Map<int, String> groupAdminLastNames = {};
    final List<Future<void>> adminNameFutures = [];

    for (var json in groupsData) {
      if (json['rank'] != 'ADMIN') {
        final groupId = json['id'];
        if (groupId != null) {
          adminNameFutures.add(() async {
            try {
              final members = await apiService.getGroupMembers(token, groupId);
              final adminMember = members.firstWhere(
                (m) => m['rank'] == 'ADMIN',
                orElse: () => <String, dynamic>{},
              );

              if (adminMember.isNotEmpty && adminMember['user'] != null) {
                final user = adminMember['user'] as Map<String, dynamic>;
                final firstName = user['first_name']?.toString() ?? '';
                final lastName = user['last_name']?.toString() ?? '';
                final nickname = user['nickname']?.toString() ?? '';
                final username = user['username']?.toString() ?? '';

                // Store first and last name separately
                groupAdminFirstNames[groupId] = firstName;
                groupAdminLastNames[groupId] = lastName;

                // Prioritize full name over nickname
                String displayName = 'Admin';
                if (firstName.isNotEmpty || lastName.isNotEmpty) {
                  displayName = '$lastName $firstName'.trim();
                } else if (nickname.isNotEmpty) {
                  displayName = nickname;
                } else if (username.isNotEmpty) {
                  displayName = username;
                }
                groupAdminNames[groupId] = displayName;
              }
            } catch (e) {
              debugPrint('Error fetching admin for group $groupId: $e');
            }
          }());
        }
      }
    }

    // Fetch Quizzes for each group to determine active tests
    final Map<int, List<Map<String, dynamic>>> groupAllActiveQuizzes = {};
    final List<Future<void>> quizFutures = [];

    for (var json in groupsData) {
      final groupId = json['id'];
      if (groupId != null) {
        quizFutures.add(() async {
          try {
            final quizzes = await apiService.getGroupQuizzes(token, groupId);
            final now = DateTime.now();

            final activeQuizzes = quizzes.where((q) {
              final end = DateTime.tryParse(q['date_end'] ?? '');
              final start = DateTime.tryParse(q['date_start'] ?? '');
              return end != null &&
                  start != null &&
                  end.toLocal().isAfter(now) &&
                  start.toLocal().isBefore(now);
            }).toList();

            if (activeQuizzes.isNotEmpty) {
              // Sort by end date (closest to expiry first)
              activeQuizzes.sort((a, b) {
                final endA = DateTime.parse(a['date_end']);
                final endB = DateTime.parse(b['date_end']);
                return endA.compareTo(endB);
              });
              groupAllActiveQuizzes[groupId] = activeQuizzes;
            }
          } catch (e) {
            debugPrint('Error fetching quizzes for group $groupId: $e');
          }
        }());
      }
    }

    await Future.wait([...adminNameFutures, ...quizFutures]);

    if (!mounted) return;

    setState(() {
      final allGroups = groupsData.map((json) {
        // Parse color from hex string
        Color groupColor = Colors.blue;
        if (json['color'] != null) {
          try {
            String colorStr = json['color'].toString();
            if (colorStr.startsWith('#')) {
              colorStr = colorStr.substring(1);
            }
            if (colorStr.length == 6) {
              groupColor = Color(int.parse('FF$colorStr', radix: 16));
            }
          } catch (e) {
            debugPrint('Color parsing error: $e');
          }
        }

        // ADMIN rank means teacher/admin
        final isAdmin = json['rank'] == 'ADMIN';
        final groupId = json['id'];

        // Extract instructor first and last name separately
        String instructorFirstName = '';
        String instructorLastName = '';

        if (isAdmin) {
          // If I am admin, use my name from UserProvider
          final user = userProvider.user;
          if (user != null) {
            instructorFirstName = user.firstName;
            instructorLastName = user.lastName;
          }
        } else {
          // First try to get from members API lookup
          if (groupId != null && groupAdminFirstNames.containsKey(groupId)) {
            instructorFirstName = groupAdminFirstNames[groupId]!;
            instructorLastName = groupAdminLastNames[groupId] ?? '';
          }
          // Fall back to owner object in API response
          else if (json['owner'] != null && json['owner'] is Map) {
            final owner = json['owner'];
            instructorFirstName = owner['first_name']?.toString() ?? '';
            instructorLastName = owner['last_name']?.toString() ?? '';
          }
        }

        // Resolve owner name (Teacher's Full Name) for display
        String ownerName = (() {
          if (isAdmin) {
            final user = userProvider.user;
            if (user != null &&
                (user.firstName.isNotEmpty || user.lastName.isNotEmpty)) {
              return '${user.lastName} ${user.firstName}'.trim();
            }
            return user?.username ?? 'Én';
          }

          // 1. Try fetched admin name (from group members lookup)
          if (groupId != null && groupAdminNames.containsKey(groupId)) {
            return groupAdminNames[groupId]!;
          }

          // 2. Try owner_name field (API provided name)
          if (json['owner_name'] != null &&
              json['owner_name'].toString().isNotEmpty) {
            return json['owner_name'].toString();
          }

          if (instructorFirstName.isNotEmpty || instructorLastName.isNotEmpty) {
            return '$instructorLastName $instructorFirstName'.trim();
          }

          return 'Admin';
        })();

        // Determine active quiz data
        bool hasNotification = false;
        DateTime? testExpiry;
        String? activeTestTitle;
        Map<String, dynamic>? primaryActiveQuiz;
        List<Map<String, dynamic>> allActiveQuizzes = [];

        if (groupId != null && groupAllActiveQuizzes.containsKey(groupId)) {
          allActiveQuizzes = groupAllActiveQuizzes[groupId]!;
          if (allActiveQuizzes.isNotEmpty) {
            primaryActiveQuiz = allActiveQuizzes.first;
            hasNotification = true;
            testExpiry = DateTime.parse(
              primaryActiveQuiz['date_end'],
            ).toLocal();

            if (primaryActiveQuiz['project_name'] != null) {
              activeTestTitle = primaryActiveQuiz['project_name'];
            } else {
              activeTestTitle = 'Aktív Teszt';
            }
          }
        }

        return Group(
          id: groupId,
          title: json['name'] ?? 'Névtelen csoport',
          ownerName: ownerName,
          instructorFirstName: instructorFirstName,
          instructorLastName: instructorLastName,
          subtitle: isAdmin ? '' : ownerName, // Logic for Home Page Card
          color: groupColor,
          inviteCode: json['invite_code'],
          inviteCodeFormatted: json['invite_code_formatted'],
          rank: json['rank'] ?? 'MEMBER',
          hasNotification: hasNotification,
          testExpiryDate: testExpiry,
          activeTestTitle: activeTestTitle,
          activeQuizData: primaryActiveQuiz,
          allActiveQuizzes: allActiveQuizzes, // Pass all active quizzes
          anticheat:
              json['anticheat'] ?? false, // Protection level: Nyitott default
          kiosk: json['kiosk'] ?? false, // Kiosk mode default disabled
        );
      }).toList();

      _myGroups = allGroups.where((g) => g.rank == 'ADMIN').toList();
      _otherGroups = allGroups.where((g) => g.rank != 'ADMIN').toList();

      if (_selectedGroup != null) {
        // Update selected group with fresh data
        _selectedGroup = allGroups.firstWhere(
          (g) => g.id == _selectedGroup!.id,
          orElse: () => _selectedGroup!,
        );
      }

      _cleanupExpiredNotifications();
      _activeTests = _getActiveTests();
      _isLoading = false;
    });
  }

  void _cleanupExpiredNotifications() {
    final now = DateTime.now();
    _myGroups = _myGroups.map((group) {
      if (group.testExpiryDate?.isBefore(now) ?? false) {
        return group.copyWith(hasNotification: false);
      }
      return group;
    }).toList();
    _otherGroups = _otherGroups.map((group) {
      if (group.testExpiryDate?.isBefore(now) ?? false) {
        return group.copyWith(hasNotification: false);
      }
      return group;
    }).toList();
  }

  void _handleTestExpired(ActiveTestItem expiredItem) {
    setState(() {
      final expiredGroup = expiredItem.group;
      int otherIndex = _otherGroups.indexWhere(
        (g) => g.title == expiredGroup.title,
      );
      if (otherIndex != -1) {
        _otherGroups[otherIndex] = _otherGroups[otherIndex].copyWith(
          hasNotification: false,
        );
      } else {
        int myIndex = _myGroups.indexWhere(
          (g) => g.title == expiredGroup.title,
        );
        if (myIndex != -1) {
          _myGroups[myIndex] = _myGroups[myIndex].copyWith(
            hasNotification: false,
          );
        }
      }

      if (_selectedGroup != null &&
          _selectedGroup!.title == expiredGroup.title) {
        _selectedGroup = _selectedGroup!.copyWith(hasNotification: false);
      }

      _activeTests = _getActiveTests();
    });
  }

  void _selectGroup(Group group) {
    setState(() {
      _selectedGroup = group;
    });
    _fetchGroups();
  }

  void _unselectGroup() {
    setState(() {
      _selectedGroup = null;
      _isMemberPanelOpen = false;
    });
  }

  Future<void> _showJoinGroupDialog() async {
    final inviteCode = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(opacity: a1, child: const _JoinGroupDialog()),
        );
      },
    );

    if (inviteCode != null && inviteCode.isNotEmpty) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hiba: Nincs bejelentkezve')),
          );
        }
        return;
      }

      final apiService = ApiService();
      final groupData = await apiService.joinGroup(token, inviteCode.trim());

      if (!mounted) return;

      if (groupData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sikeresen csatlakoztál a csoporthoz: ${groupData['name'] ?? 'Csoport'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchGroups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba: Érvénytelen meghívó kód'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTutorial() {
    late TutorialCoachMark tutorialCoachMark;
    List<TargetFocus> targets = [];

    // 1. Welcome / Help Button
    targets.add(
      TargetFocus(
        identify: "tutorial_btn",
        keyTarget: _tutorialButtonKey,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        enableTargetTab: true,
        shape: ShapeLightFocus.Circle,
        radius: 10,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Üdvözölleg a cQuizy-ben!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Ez az interaktív bemutató végigvezet a legfontosabb funkciókon, beleértve a csoport létrehozását is. Bármikor újraindíthatod ezzel a gombbal.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 2. Side Navigation
    targets.add(
      TargetFocus(
        identify: "side_nav",
        keyTarget: _sideNavKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 10,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Navigációs Menü",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Itt válthatsz a Projekt szerkesztő, Csoportok és Beállítások között. Itt látod majd az éppen futó teszteket is.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 3. Speed Dial Button
    targets.add(
      TargetFocus(
        identify: "speed_dial",
        keyTarget: _speedDialKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        radius: 10,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Műveletek Menü",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Kattints ide a műveletek megnyitásához. Itt hozhatsz létre új projekteket, csoportokat, vagy csatlakozhatsz meglévőkhöz.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Kihagyás",
      paddingFocus: 0,
      opacityShadow: 0.9,
      pulseEnable: true,
      onFinish: () {
        debugPrint("Tutorial finished - opening speed dial");
        // Open speed dial after tutorial finishes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSpeedDialOpen = true;
            });
          }
        });
        // Wait longer for SpeedDial animation to finish to avoid "target position" errors
        Future.delayed(const Duration(milliseconds: 1200), () {
          try {
            if (mounted && _isSpeedDialOpen) {
              // Helper function to check if widget is visible and laid out
              bool isKeyReady(GlobalKey key) {
                final context = key.currentContext;
                if (context == null) return false;
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox == null || !renderBox.hasSize) return false;
                return renderBox.size.width > 0 && renderBox.size.height > 0;
              }

              // Check if the key exists AND has a valid size
              if (isKeyReady(_createGroupButtonKey)) {
                _showCreateGroupTutorial();
              } else {
                debugPrint(
                  "Target key not ready (null or 0 size), retrying...",
                );
                Future.delayed(const Duration(milliseconds: 600), () {
                  try {
                    if (mounted &&
                        _isSpeedDialOpen &&
                        isKeyReady(_createGroupButtonKey)) {
                      _showCreateGroupTutorial();
                    } else {
                      debugPrint(
                        "Target key still not ready, skipping tutorial step to avoid crash.",
                      );
                    }
                  } catch (e) {
                    debugPrint("TUTORIAL ERROR in retry: $e");
                  }
                });
              }
            }
          } catch (e, s) {
            debugPrint("TUTORIAL ERROR in HomePage onFinish: $e");
            debugPrint(s.toString());
          }
        });
      },
      onClickTarget: (target) {
        debugPrint("onClickTarget: $target");
      },
      onSkip: () {
        debugPrint("Tutorial skipped");
        return true;
      },
      onClickOverlay: (target) {
        debugPrint("onClickOverlay: $target");
      },
    );

    tutorialCoachMark.show(context: context);
  }

  Future<void> _importProject() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Projekt importálása',
        type: FileType.custom,
        allowedExtensions: ['cq'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        final String content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final api = ApiService();
        // Create new project
        final name = data['name'] ?? 'Importált projekt';
        final desc = data['desc'] ?? '';
        final newProject = await api.createProject(token, name, desc);

        if (newProject != null) {
          final newId = newProject['id'];
          // Update blocks
          if (data['blocks'] != null) {
            final blocks = List<Map<String, dynamic>>.from(
              (data['blocks'] as List).map((item) {
                // Deep copy and reset IDs
                final block = jsonDecode(jsonEncode(item));
                block['id'] = 0;
                if (block['answers'] != null) {
                  for (var ans in block['answers']) {
                    ans['id'] = 0;
                  }
                }
                return block;
              }),
            );
            await api.updateProject(token, newId, {
              'name': name,
              'desc': desc,
              'blocks': blocks,
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Projekt sikeresen importálva!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            // Refresh projects list
            setState(() {
              _projectsRefreshKey++;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba az importálás során: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showCreateGroupTutorial() {
    late TutorialCoachMark tutorialCoachMark;
    List<TargetFocus> targets = [];

    // Highlight the Create Group button
    targets.add(
      TargetFocus(
        identify: "create_group_btn",
        keyTarget: _createGroupButtonKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Csoport Létrehozás",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Kattints ide egy új csoport létrehozásához! Most végigvezetlek a teljes folyamaton.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Kihagyás",
      paddingFocus: 0,
      opacityShadow: 0.9,
      pulseEnable: true,
      onFinish: () {
        debugPrint("Create group tutorial flow finished");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSpeedDialOpen = false;
            });
          }
        });
      },
      onClickTarget: (target) async {
        debugPrint("onClickTarget: $target");
        // Prevent double navigation if onFinish fires
        if (_isNavigatingToCreateGroup) return;
        _isNavigatingToCreateGroup = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSpeedDialOpen = false;
            });
          }
        });

        // Navigate immediately when user clicks the button
        bool? result;
        try {
          result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateGroupPage(tutorialMode: true),
            ),
          );
        } finally {
          _isNavigatingToCreateGroup = false;
        }

        // If tutorial finished successfully, continue to Project Creation
        if (result == true && mounted) {
          // Small delay to allow UI to settle
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showCreateProjectTutorial();
          });
        }

        _fetchGroups();
      },
      onSkip: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSpeedDialOpen = false;
            });
          }
        });
        return true;
      },
    );

    tutorialCoachMark.show(context: context);
  }

  void _showCreateProjectTutorial() {
    _isInProjectTutorial = true;
    late TutorialCoachMark tutorialCoachMark;
    List<TargetFocus> targets = [];

    // 1. Projects Tab
    targets.add(
      TargetFocus(
        identify: "projects_tab",
        keyTarget: _projectsNavKey,
        alignSkip: Alignment.centerRight,
        shape: ShapeLightFocus.RRect,
        radius: 10,
        contents: [
          TargetContent(
            align: ContentAlign.right,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Projektek",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Kattints ide a Projektek nézet megnyitásához! Itt hozhatod létre és kezelheted a feladatsorokat.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 2. Create Project Button
    targets.add(
      TargetFocus(
        identify: "create_project_btn",
        keyTarget: _createProjectButtonKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Új Projekt",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Kattints ide egy új projekt létrehozásához! Adj neki nevet és leírást.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Kihagyás",
      paddingFocus: 0,
      opacityShadow: 0.9,
      pulseEnable: true,
      onFinish: () {
        debugPrint("Project tutorial finished");
        _isInProjectTutorial = false;
      },
      onClickTarget: (target) {
        if (target.identify == "projects_tab") {
          // Ensure we switch to projects tab
          if (mounted) {
            setState(() {
              _showProjects = true;
              _selectedGroup = null;
              // Open speed dial for next step
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) setState(() => _isSpeedDialOpen = true);
              });
            });
          }
        }
      },
      onSkip: () {
        return true;
      },
    );

    // Ensure speed dial is closed initially so user focuses on SideNav
    if (_isSpeedDialOpen) setState(() => _isSpeedDialOpen = false);

    tutorialCoachMark.show(context: context);
  }

  bool _isNavigatingToCreateGroup = false;

  void _toggleSpeedDial() {
    ThemeInherited.of(context).triggerHaptic();
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > kDesktopBreakpoint;
        final bool isGroupView = _selectedGroup != null;

        if (isDesktop) {
          // --- ASZTALI NÉZET ---
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                Container(key: _sideNavKey, child: _buildSideNav(_activeTests)),
                Expanded(
                  child: Stack(
                    children: [
                      _buildAnimatedContent(),
                      // A "Vissza" gomb csak akkor jelenik meg, ha egy csoport ki van választva
                      if (isGroupView)
                        Positioned(
                          bottom: 24,
                          left: 24,
                          child: _buildMenuButton(
                            icon: Icons.arrow_back,
                            tooltip: 'Vissza',
                            onPressed: _unselectGroup,
                          ),
                        ),
                      if (!_showStudentTests && !_showStatistics)
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _isMemberPanelOpen ? 0.0 : 1.0,
                            child: IgnorePointer(
                              ignoring: _isMemberPanelOpen,
                              child: _buildSpeedDial(
                                context,
                                isGroupView: isGroupView,
                              ),
                            ),
                          ),
                        ),

                      // Tutorial / Help Button (Top Right)
                      if (!isGroupView && !_showProjects)
                        Positioned(
                          top: 24,
                          right: 24,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isTutorialButtonVisible ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: !_isTutorialButtonVisible,
                              child: Material(
                                color: Theme.of(context).cardColor,
                                elevation: 4,
                                type: MaterialType.circle,
                                child: Tooltip(
                                  message: 'Interaktív Súgó',
                                  child: InkWell(
                                    key: _tutorialButtonKey,
                                    onTap: _showTutorial,
                                    customBorder: const CircleBorder(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Icon(
                                        Icons.help_outline_rounded,
                                        color: Theme.of(context).primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          // --- MOBIL NÉZET ---
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            extendBody: true, // Allow background to flow behind bottom bar
            drawer: _buildSideNav(_activeTests, isDrawer: true),
            onDrawerChanged: (isOpened) {
              if (!isOpened) {
                setState(() {
                  _isBottomBarVisible = true;
                });
              }
            },
            body: SafeArea(bottom: false, child: _buildAnimatedContent()),
            bottomNavigationBar: _isBottomBarVisible && !_isMemberPanelOpen
                ? IgnorePointer(
                    ignoring: _isMemberPanelOpen,
                    child: Container(
                      color: Colors.transparent,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Builder(
                                builder: (context) => _buildMenuButton(
                                  icon: isGroupView
                                      ? Icons.arrow_back
                                      : Icons.menu_rounded,
                                  tooltip: isGroupView ? 'Vissza' : 'Menü',
                                  onPressed: () {
                                    if (isGroupView) {
                                      _unselectGroup();
                                    } else {
                                      setState(() {
                                        _isBottomBarVisible = false;
                                      });
                                      Scaffold.of(context).openDrawer();
                                    }
                                  },
                                ),
                              ),
                              const Spacer(),
                              if (!_showStudentTests && !_showStatistics)
                                _buildSpeedDial(
                                  context,
                                  isGroupView: isGroupView,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          );
        }
      },
    );
  }

  // Az animált tartalomváltó
  Widget _buildAnimatedContent() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final isVisible = notification.metrics.pixels < 50;
          if (_isTutorialButtonVisible != isVisible) {
            setState(() {
              _isTutorialButtonVisible = isVisible;
            });
          }
        }
        return false;
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _selectedGroup != null
            ? GroupPage(
                key: ValueKey(_selectedGroup!.title),
                group: _selectedGroup!,
                onTestExpired: (group) => _fetchGroups(),
                onMemberPanelToggle: (isOpen) {
                  setState(() {
                    _isMemberPanelOpen = isOpen;
                  });
                },
                onAdminTransferred: () async {
                  _unselectGroup();
                  await _fetchGroups();
                },
                onGroupUpdated: () async {
                  final currentGroupId = _selectedGroup?.id;
                  await _fetchGroups();
                  if (currentGroupId != null) {
                    final allGroups = [..._myGroups, ..._otherGroups];
                    final updatedGroup = allGroups.firstWhere(
                      (g) => g.id == currentGroupId,
                      orElse: () => _selectedGroup!,
                    );
                    setState(() {
                      _selectedGroup = updatedGroup;
                    });
                  }
                },
                onGroupLeft: () async {
                  _unselectGroup();
                  await _fetchGroups();
                },
              )
            : _showProjects
            ? ProjectsPage(key: ValueKey('projects_$_projectsRefreshKey'))
            : _showStudentTests
            ? const StudentTestsPage()
            : _showStatistics
            ? const StatisticsPage()
            : _buildGroupList(),
      ),
    );
  }

  Widget _buildSpeedDial(BuildContext context, {required bool isGroupView}) {
    final theme = Theme.of(context);

    Widget buildLabel(String text) {
      return Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    if (_showProjects) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Import Project Button
                AnimatedScale(
                  scale: _isSpeedDialOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _isSpeedDialOpen ? 1.0 : 0.0,
                    child: _isSpeedDialOpen
                        ? Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildLabel('Projekt importálása'),
                                Tooltip(
                                  message: 'Projekt importálása fájlból',
                                  child: InkWell(
                                    onTap: () {
                                      ThemeInherited.of(
                                        context,
                                      ).triggerHaptic();
                                      setState(() {
                                        _isSpeedDialOpen = false;
                                      });
                                      _importProject();
                                    },
                                    customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(
                                          0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.upload_file,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // Create Project Button
                AnimatedScale(
                  scale: _isSpeedDialOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _isSpeedDialOpen ? 1.0 : 0.0,
                    child: _isSpeedDialOpen
                        ? Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildLabel('Projekt létrehozása'),
                                Tooltip(
                                  message: 'Új projekt létrehozása',
                                  child: InkWell(
                                    key: _createProjectButtonKey,
                                    onTap: () async {
                                      ThemeInherited.of(
                                        context,
                                      ).triggerHaptic();
                                      setState(() {
                                        _isSpeedDialOpen = false;
                                      });
                                      final result =
                                          await showGeneralDialog<
                                            Map<String, String>
                                          >(
                                            context: context,
                                            barrierDismissible: true,
                                            barrierLabel: '',
                                            transitionDuration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            pageBuilder:
                                                (
                                                  context,
                                                  animation1,
                                                  animation2,
                                                ) {
                                                  return Container();
                                                },
                                            transitionBuilder:
                                                (context, a1, a2, widget) {
                                                  return ScaleTransition(
                                                    scale: Tween<double>(
                                                      begin: 0.5,
                                                      end: 1.0,
                                                    ).animate(a1),
                                                    child: FadeTransition(
                                                      opacity: a1,
                                                      child: CreateProjectDialog(
                                                        tutorialMode:
                                                            _isInProjectTutorial,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          );

                                      if (result != null) {
                                        final userProvider =
                                            Provider.of<UserProvider>(
                                              context,
                                              listen: false,
                                            );
                                        final token = userProvider.token;
                                        if (token != null) {
                                          final api = ApiService();
                                          final project = await api
                                              .createProject(
                                                token,
                                                result['name']!,
                                                result['desc']!,
                                              );
                                          if (mounted) {
                                            if (project != null) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Projekt sikeresen létrehozva!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              setState(() {
                                                _projectsRefreshKey++;
                                              });
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Hiba a projekt létrehozása során',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    },
                                    customBorder: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(
                                          0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          // Main Toggle Button
          Tooltip(
            message: _isSpeedDialOpen ? 'Bezárás' : 'Projekt műveletek',
            child: InkWell(
              onTap: _toggleSpeedDial,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  turns: _isSpeedDialOpen ? 0.125 : 0,
                  child: Icon(
                    _isSpeedDialOpen ? Icons.close : Icons.add,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isGroupView) {
      final isAdmin = _selectedGroup?.rank == 'ADMIN';

      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isAdmin ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isAdmin ? 1.0 : 0.0,
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !isAdmin,
            child: Tooltip(
              message: 'Új teszt kiírása',
              child: InkWell(
                onTap: () async {
                  if (_selectedGroup != null && _selectedGroup!.id != null) {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) =>
                          CreateQuizDialog(groupId: _selectedGroup!.id!),
                    );
                    if (result == true) {
                      _fetchGroups();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teszt sikeresen kiírva!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
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
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedScale(
                scale: _isSpeedDialOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _isSpeedDialOpen ? 1.0 : 0.0,
                  child: _isSpeedDialOpen
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              buildLabel('Csatlakozás'),
                              Tooltip(
                                message: 'Csatlakozás csoporthoz',
                                child: InkWell(
                                  onTap: () {
                                    ThemeInherited.of(context).triggerHaptic();
                                    setState(() {
                                      _isSpeedDialOpen = false;
                                    });
                                    _showJoinGroupDialog();
                                  },
                                  customBorder: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: const Icon(
                                      Icons.group_add,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              AnimatedScale(
                scale: _isSpeedDialOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _isSpeedDialOpen ? 1.0 : 0.0,
                  child: _isSpeedDialOpen
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              buildLabel('Új csoport'),
                              Tooltip(
                                message: 'Csoport létrehozása',
                                child: InkWell(
                                  key: _createGroupButtonKey,
                                  onTap: () async {
                                    ThemeInherited.of(context).triggerHaptic();
                                    setState(() {
                                      _isSpeedDialOpen = false;
                                    });
                                    final result = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CreateGroupPage(),
                                      ),
                                    );
                                    if (result == true) {
                                      _fetchGroups();
                                    }
                                  },
                                  customBorder: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        // Main
        Tooltip(
          message: _isSpeedDialOpen ? 'Bezárás' : 'Csoport művelet',
          child: InkWell(
            key: _speedDialKey,
            onTap: _toggleSpeedDial,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                turns: _isSpeedDialOpen ? 0.125 : 0, // 45 degrees rotation
                child: Icon(
                  _isSpeedDialOpen ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Segédfüggvény a menü/vissza gomb kirajzolásához
  Widget _buildMenuButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            ThemeInherited.of(context).triggerHaptic();
            onPressed();
          },
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // A csoportlista
  Widget _buildGroupList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return ListView(
          key: const ValueKey('group_list'),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 20.0 : 40.0),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20.0 : 40.0),
              child: const HeaderWithDivider(title: 'Saját Csoportok'),
            ),
            SizedBox(height: isMobile ? 12 : 20),
            ..._myGroups
                .map(
                  (group) =>
                      GroupCard(group: group, onGroupSelected: _selectGroup),
                )
                .toList(),
            SizedBox(height: isMobile ? 20 : 30),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20.0 : 40.0),
              child: const HeaderWithDivider(title: 'További Csoportok'),
            ),
            SizedBox(height: isMobile ? 12 : 20),
            ..._otherGroups
                .map(
                  (group) =>
                      GroupCard(group: group, onGroupSelected: _selectGroup),
                )
                .toList(),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  // Oldalsó menü / Drawer
  Widget _buildSideNav(
    List<ActiveTestItem> activeTests, {
    bool isDrawer = false,
  }) {
    final theme = Theme.of(context);
    final navContent = Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SideNavItem(
                    label: 'Csoportok',
                    icon: Icons.group,
                    isSelected:
                        _selectedGroup == null &&
                        !_showProjects &&
                        !_showStudentTests &&
                        !_showStatistics,
                    onTap: () {
                      if (_selectedGroup != null ||
                          _showProjects ||
                          _showStudentTests ||
                          _showStatistics) {
                        setState(() {
                          _showProjects = false;
                          _showStudentTests = false;
                          _showStatistics = false;
                          _selectedGroup = null;
                        });
                      }
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  SideNavItem(
                    key: _projectsNavKey,
                    label: 'Projektek',
                    icon: Icons.folder,
                    isSelected: _showProjects,
                    onTap: () {
                      if (!_showProjects) {
                        setState(() {
                          _showProjects = true;
                          _showStudentTests = false;
                          _showStatistics = false;
                          _selectedGroup = null;
                          _isMemberPanelOpen = false;
                        });
                      }
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  SideNavItem(
                    label: 'Tesztek',
                    icon: Icons.quiz,
                    isSelected: _showStudentTests,
                    onTap: () {
                      if (!_showStudentTests) {
                        setState(() {
                          _showStudentTests = true;
                          _showProjects = false;
                          _showStatistics = false;
                          _selectedGroup = null;
                          _isMemberPanelOpen = false;
                        });
                      }
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  SideNavItem(
                    label: 'Statisztika',
                    icon: Icons.bar_chart,
                    isSelected: _showStatistics,
                    onTap: () {
                      if (!_showStatistics) {
                        setState(() {
                          _showStatistics = true;
                          _showProjects = false;
                          _showStudentTests = false;
                          _selectedGroup = null;
                          _isMemberPanelOpen = false;
                        });
                      }
                      if (isDrawer) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('assets/logo/logo_2.png', height: 16),
              const SizedBox(width: 8),
              Text(
                'cQuizy',
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Divider(color: theme.dividerColor),
          const SizedBox(height: 10),
          if (activeTests.isNotEmpty)
            ActiveTestCarousel(
              key: ValueKey(activeTests.map((item) => item.title).join()),
              activeTests: activeTests,
              onExpired: _handleTestExpired,
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          // Profil & Beállítások with profile picture
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              final user = userProvider.user;
              final pfpUrl = user?.pfpUrl;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.15),
                      theme.primaryColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SettingsPage(onLogout: widget.onLogout),
                        ),
                      );
                      _fetchGroups();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.primaryColor,
                              backgroundImage:
                                  pfpUrl != null && pfpUrl.isNotEmpty
                                  ? NetworkImage(pfpUrl)
                                  : null,
                              child: pfpUrl == null || pfpUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profil és Beállítások',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.nickname ??
                                      user?.username ??
                                      'Felhasználó',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.settings_outlined,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),
        ],
      ),
    );

    return isDrawer ? Drawer(child: navContent) : navContent;
  }
}

// --- LOKÁLIS WIDGETEK ---

class SideNavItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const SideNavItem({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Színkódok és stílusok definiálása az állapottól függően
    final backgroundColor = isSelected
        ? theme.primaryColor.withOpacity(0.1)
        : Colors.transparent;

    final iconBackgroundColor = isSelected
        ? theme.primaryColor
        : theme.colorScheme.surfaceContainerHighest;

    final iconColor = isSelected
        ? Colors.white
        : theme.iconTheme.color?.withOpacity(0.7);

    final textColor = isSelected
        ? theme.primaryColor
        : theme.textTheme.bodyLarge?.color?.withOpacity(0.8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBackgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ActiveTestCard extends StatefulWidget {
  final ActiveTestItem item;
  final VoidCallback onExpired;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const ActiveTestCard({
    super.key,
    required this.item,
    required this.onExpired,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<ActiveTestCard> createState() => _ActiveTestCardState();
}

class _ActiveTestCardState extends State<ActiveTestCard> {
  bool _isHovered = false;

  void _showStartTestConfirmation(
    BuildContext context,
    Map<String, dynamic> quiz,
  ) {
    if (kIsWeb && widget.item.group.kiosk) {
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
                                        ?.withOpacity(0.6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  WebProtections.enterFullScreen(); // Request browser fullscreen on user gesture
                                  Navigator.pop(context); // Close dialog

                                  // Prepare quiz object with group back-reference
                                  final quizData = Map<String, dynamic>.from(
                                    quiz,
                                  );
                                  quizData['group_obj'] = widget.item.group;

                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TestTakingPage(
                                        quiz: quizData,
                                        groupName: widget.item.group.title,
                                        anticheat: widget.item.group.anticheat,
                                        kiosk: widget.item.group.kiosk,
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

  @override
  Widget build(BuildContext context) {
    final group = widget.item.group;
    final isAdmin = group.rank == 'ADMIN';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: group.getGradient(context),
              borderRadius: BorderRadius.circular(14),
              border: isAdmin
                  ? Border.all(color: Theme.of(context).primaryColor, width: 3)
                  : null,
              boxShadow: isAdmin
                  ? [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: TextStyle(
                          color: group.getTextColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent, // Badge color
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SAJÁT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  widget.item.title, // Use item title
                  style: TextStyle(
                    color: group.getTextColor(context).withOpacity(0.9),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const Spacer(),
                if (widget.item.expiryDate.isAfter(DateTime.now()))
                  Center(
                    child: CountdownTimerWidget(
                      expiryDate: widget.item.expiryDate, // Use item expiry
                      onExpired: widget.onExpired,
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (isAdmin) {
                      // Only Admin can open admin page for specific quiz
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminPage(
                            quiz: widget.item.quiz, // Use item quiz
                            groupId: group.id!,
                            groupName: group.title,
                          ),
                        ),
                      );
                    } else {
                      _showStartTestConfirmation(context, widget.item.quiz);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isAdmin ? 'Admin felület' : 'Teszt Indítása',
                        style: TextStyle(
                          color: group.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.play_arrow,
                        size: 20,
                        color: group.getTextColor(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          AnimatedOpacity(
            opacity: _isHovered && widget.onPrevious != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildNavArrow(
                icon: Icons.arrow_back_ios_new,
                onTap: widget.onPrevious,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _isHovered && widget.onNext != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildNavArrow(
                icon: Icons.arrow_forward_ios,
                onTap: widget.onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavArrow({required IconData icon, VoidCallback? onTap}) {
    if (onTap == null) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
      ),
    );
  }
}

class ActiveTestCarousel extends StatefulWidget {
  final List<ActiveTestItem> activeTests;
  final Function(ActiveTestItem) onExpired;

  const ActiveTestCarousel({
    super.key,
    required this.activeTests,
    required this.onExpired,
  });

  @override
  State<ActiveTestCarousel> createState() => _ActiveTestCarouselState();
}

class _ActiveTestCarouselState extends State<ActiveTestCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (widget.activeTests.length > 1) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!mounted || widget.activeTests.length < 2) {
        timer.cancel();
        return;
      }
      int nextPage = _currentPage < widget.activeTests.length - 1
          ? _currentPage + 1
          : 0;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _timer?.cancel(),
      onExit: (_) => _startTimer(),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 240 / 185,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.activeTests.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
                // Only reset timer if not hovered?
                // Actually, if hovered, timer is canceled.
                // If we manually change page via arrows, we should probably restart timer only if not hovered.
                // But simplified logic: cancelling on enter is enough.
                // If manual nav happens, it implies hover, so timer is off.
              },
              itemBuilder: (context, index) {
                final item = widget.activeTests[index];
                return ActiveTestCard(
                  key: ValueKey('${item.group.id}_${item.quiz['id']}'),
                  item: item,
                  onExpired: () => widget.onExpired(item),
                  onNext: index < widget.activeTests.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  onPrevious: index > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                );
              },
            ),
          ),
          if (widget.activeTests.length > 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.activeTests.length,
                  (index) => buildDot(index: index),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white54,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class GroupCard extends StatelessWidget {
  final Group group;
  final Function(Group) onGroupSelected;

  const GroupCard({
    super.key,
    required this.group,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              constraints: const BoxConstraints(),
              margin: EdgeInsets.only(
                bottom: isMobile ? 12.0 : 16.0,
                left: isMobile ? 12.0 : 16.0,
                right: isMobile ? 12.0 : 16.0,
              ),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: group.getGradient(context),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onGroupSelected(group),
                  borderRadius: BorderRadius.circular(5),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20.0 : 40.0,
                      vertical: isMobile ? 14.0 : 20.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: TextStyle(
                            color: group.getTextColor(context),
                            fontSize: isMobile ? 18 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isMobile ? 2 : 4),
                        Text(
                          group.subtitle,
                          style: TextStyle(
                            color: group.getTextColor(context).withOpacity(0.8),
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (group.hasNotification)
              Positioned(
                right: isMobile ? 20 : 25,
                bottom: isMobile ? 20 : 25,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xfffdd835),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                  ),
                ),
              ),
          ],
        );
      },
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
            color: theme.textTheme.titleMedium?.color?.withOpacity(0.8),
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

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withValues(alpha: 0.7),
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
                      Icons.group_add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Csatlakozás csoporthoz',
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
                final hPadding = constraints.maxWidth < 400 ? 20.0 : 32.0;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPadding,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Add meg a csoport meghívó kódját:',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Meghívó kód',
                          hintText: 'pl. ABC123',
                          prefixIcon: Icon(
                            Icons.vpn_key,
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
                        textCapitalization: TextCapitalization.characters,
                        autofocus: true,
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
                            onPressed: () => Navigator.pop(context, null),
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
                            onPressed: () =>
                                Navigator.pop(context, _controller.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: theme.primaryColor.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            child: const Text(
                              'Csatlakozás',
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
  }
}
