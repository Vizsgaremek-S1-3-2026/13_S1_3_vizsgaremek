import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'group_page.dart';
import 'settings_page.dart';
import 'create_group_page.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

const double kDesktopBreakpoint = 900.0;

class HomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Group> _myGroups;
  late List<Group> _otherGroups;
  late List<Group> _activeTests;
  Group? _selectedGroup;

  bool _isBottomBarVisible = true;
  bool _isMemberPanelOpen = false;
  bool _isSpeedDialOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
  }

  List<Group> _getActiveTests() {
    return [..._myGroups, ..._otherGroups]
        .where(
          (group) =>
              group.hasNotification &&
              group.testExpiryDate != null &&
              group.testExpiryDate!.isAfter(DateTime.now()),
        )
        .toList();
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
    if (token == null) return;

    final apiService = ApiService();
    List<dynamic> groupsData;
    try {
      groupsData = await apiService.getUserGroups(token);
    } catch (e) {
      debugPrint('Error fetching groups: $e');
      return;
    }

    // Fetch admin names for groups where I am not the admin
    final Map<int, String> groupAdminNames = {};
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
                final nickname = user['nickname']?.toString();
                final firstName = user['first_name']?.toString();
                final lastName = user['last_name']?.toString();
                final username = user['username']?.toString();

                String displayName = 'Admin';
                if (nickname != null && nickname.isNotEmpty) {
                  displayName = nickname;
                } else if (firstName != null &&
                    firstName.isNotEmpty &&
                    lastName != null &&
                    lastName.isNotEmpty) {
                  displayName = '$lastName $firstName'.trim();
                } else if (username != null && username.isNotEmpty) {
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

    if (adminNameFutures.isNotEmpty) {
      await Future.wait(adminNameFutures);
    }

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

        return Group(
          id: groupId,
          title: json['name'] ?? 'Névtelen csoport',
          subtitle: () {
            if (isAdmin) {
              return 'Te vagy az admin';
            }

            // 1. Try fetched admin name
            if (groupId != null && groupAdminNames.containsKey(groupId)) {
              return groupAdminNames[groupId]!;
            }

            // Try to find admin name from API response
            if (json['owner_name'] != null &&
                json['owner_name'].toString().isNotEmpty) {
              return json['owner_name'].toString();
            }

            if (json['owner'] != null && json['owner'] is Map) {
              final owner = json['owner'];
              final nickname = owner['nickname']?.toString();
              if (nickname != null && nickname.isNotEmpty) return nickname;

              final firstName = owner['first_name']?.toString();
              final lastName = owner['last_name']?.toString();
              if (firstName != null && firstName.isNotEmpty ||
                  lastName != null && lastName.isNotEmpty) {
                return '${lastName ?? ''} ${firstName ?? ''}'.trim();
              }

              final username = owner['username']?.toString();
              if (username != null && username.isNotEmpty) return username;
            }

            return 'Admin'; // Fallback
          }(),
          color: groupColor,
          inviteCode: json['invite_code'],
          inviteCodeFormatted: json['invite_code_formatted'],
          rank: json['rank'],
        );
      }).toList();

      // Split groups based on admin status
      _myGroups = allGroups.where((g) => g.rank == 'ADMIN').toList();
      _otherGroups = allGroups.where((g) => g.rank != 'ADMIN').toList();

      _cleanupExpiredNotifications();
      _activeTests = _getActiveTests();
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

  void _handleTestExpired(Group expiredGroup) {
    setState(() {
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
  }

  void _unselectGroup() {
    setState(() {
      _selectedGroup = null;
      _isMemberPanelOpen = false;
    });
  }

  Future<void> _showJoinGroupDialog() async {
    final inviteCodeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Csatlakozás csoporthoz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add meg a csoport meghívó kódját:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inviteCodeController,
              decoration: InputDecoration(
                labelText: 'Meghívó kód',
                hintText: 'pl. ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Csatlakozás'),
          ),
        ],
      ),
    );

    if (result == true && inviteCodeController.text.isNotEmpty) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hiba: Nincs bejelentkezve')),
        );
        return;
      }

      final apiService = ApiService();
      final groupData = await apiService.joinGroup(
        token,
        inviteCodeController.text.trim(),
      );

      if (groupData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sikeresen csatlakoztál a csoporthoz: ${groupData['name'] ?? 'Csoport'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh group list
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

    inviteCodeController.dispose();
  }

  void _toggleSpeedDial() {
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
                _buildSideNav(_activeTests),
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
                      // Speed Dial FAB for desktop
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
            drawer: _buildSideNav(_activeTests, isDrawer: true),
            onDrawerChanged: (isOpened) {
              if (!isOpened) {
                setState(() {
                  _isBottomBarVisible = true;
                });
              }
            },
            body: _buildAnimatedContent(),
            bottomNavigationBar: _isBottomBarVisible
                ? AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isMemberPanelOpen ? 0.0 : 1.0,
                    child: IgnorePointer(
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
                                _buildSpeedDial(
                                  context,
                                  isGroupView: isGroupView,
                                ),
                              ],
                            ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedGroup == null
          ? _buildGroupList()
          : GroupPage(
              key: ValueKey(_selectedGroup!.title),
              group: _selectedGroup!,
              onTestExpired: _handleTestExpired,
              onMemberPanelToggle: (isOpen) {
                setState(() {
                  _isMemberPanelOpen = isOpen;
                });
              },
              onAdminTransferred: () async {
                _unselectGroup();
                await _fetchGroups();
              },
            ),
    );
  }

  // Speed Dial Widget - Expandable FAB with two action buttons
  Widget _buildSpeedDial(BuildContext context, {required bool isGroupView}) {
    final theme = Theme.of(context);

    // If in group view, show simple add member button (only if admin)
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
            child: InkWell(
              onTap: () {},
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
      );
    }

    // Otherwise, show speed dial menu
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end, // Keep main FAB right-aligned
      children: [
        // Center the action buttons above the main FAB
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action Button 1: Join Group
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
                          child: Tooltip(
                            message: 'Csatlakozás csoporthoz',
                            child: InkWell(
                              onTap: () {
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
                                  color: theme.primaryColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.group_add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Action Button 2: Create Group
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
                          child: Tooltip(
                            message: 'Csoport létrehozása',
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isSpeedDialOpen = false;
                                });
                                // Navigate to Create Group Page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CreateGroupPage(),
                                  ),
                                );
                              },
                              customBorder: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        // Main FAB
        Tooltip(
          message: _isSpeedDialOpen ? 'Bezárás' : 'Csoport művelet',
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
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
          onTap: onPressed,
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
    return ListView(
      key: const ValueKey('group_list'),
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: HeaderWithDivider(title: 'Saját Csoportok'),
        ),
        const SizedBox(height: 20),
        ..._myGroups
            .map(
              (group) => GroupCard(group: group, onGroupSelected: _selectGroup),
            )
            .toList(),
        const SizedBox(height: 30),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: HeaderWithDivider(title: 'További Csoportok'),
        ),
        const SizedBox(height: 20),
        ..._otherGroups
            .map(
              (group) => GroupCard(group: group, onGroupSelected: _selectGroup),
            )
            .toList(),
        const SizedBox(height: 80),
      ],
    );
  }

  // Oldalsó menü / Drawer
  Widget _buildSideNav(List<Group> activeTests, {bool isDrawer = false}) {
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
          SideNavItem(
            label: 'Csoportok',
            icon: Icons.group,
            isSelected: _selectedGroup == null,
            onTap: () {
              if (_selectedGroup != null) _unselectGroup();
              if (isDrawer) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
          SideNavItem(label: 'Tesztek', icon: Icons.quiz),
          const SizedBox(height: 8),
          SideNavItem(label: 'Statisztika', icon: Icons.bar_chart),
          const Spacer(),
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
              key: ValueKey(activeTests.map((g) => g.title).join()),
              activeTests: activeTests,
              onExpired: _handleTestExpired,
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          SideNavItem(
            label: 'Profil & Beállítások',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(onLogout: widget.onLogout),
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
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isSelected
        ? theme.primaryColor
        : theme.textTheme.bodyLarge?.color;
    final iconColor = isSelected ? theme.primaryColor : theme.iconTheme.color;

    return Material(
      color: isSelected
          ? theme.primaryColor.withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: icon == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  radius: 18,
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveTestCard extends StatefulWidget {
  final Group group;
  final VoidCallback onExpired;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const ActiveTestCard({
    super.key,
    required this.group,
    required this.onExpired,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<ActiveTestCard> createState() => _ActiveTestCardState();
}

class _ActiveTestCardState extends State<ActiveTestCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    String subject = widget.group.title.split(' ')[0];

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
              gradient: widget.group.getGradient(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.title,
                  style: TextStyle(
                    color: widget.group.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '$subject Témazáró',
                  style: TextStyle(
                    color: widget.group.getTextColor(context).withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (widget.group.testExpiryDate != null)
                  Center(
                    child: CountdownTimerWidget(
                      expiryDate: widget.group.testExpiryDate!,
                      onExpired: widget.onExpired,
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
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
                        'Teszt Indítása',
                        style: TextStyle(
                          color: widget.group.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.play_arrow,
                        size: 20,
                        color: widget.group.getTextColor(context),
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
  final List<Group> activeTests;
  final Function(Group) onExpired;

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

  void _resetTimer() {
    _timer?.cancel();
    if (widget.activeTests.length > 1) {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              _resetTimer();
            },
            itemBuilder: (context, index) {
              final group = widget.activeTests[index];
              return ActiveTestCard(
                key: ValueKey(group.title),
                group: group,
                onExpired: () => widget.onExpired(group),
                onNext: index < widget.activeTests.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        _resetTimer();
                      }
                    : null,
                onPrevious: index > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        _resetTimer();
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
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Container(
          constraints: const BoxConstraints(),
          margin: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 20.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      group.title,
                      style: TextStyle(
                        color: group.getTextColor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.subtitle,
                      style: TextStyle(
                        color: group.getTextColor(context).withOpacity(0.8),
                        fontSize: 14,
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
            right: 25,
            bottom: 25,
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
