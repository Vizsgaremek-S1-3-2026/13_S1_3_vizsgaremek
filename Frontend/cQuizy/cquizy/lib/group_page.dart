// lib/group_page.dart

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter/services.dart'; // A vágólaphoz szükséges
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

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
  late List<Map<String, String>> _pastTests;
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;
  int? _expandedMemberId;

  // Customize Panel State
  bool _isCustomizePanelVisible = false;
  late TextEditingController _groupNameController;
  late Color _selectedColor;
  bool _kioskMode = false;
  bool _antiCheat = false;

  // HSL Color State
  double _hue = 0.0;
  double _saturation = 0.7;
  double _lightness = 0.6;
  bool _showCustomColorPicker = false;

  // Invite Code State
  String? _currentInviteCode;
  bool _isRegeneratingCode = false;

  @override
  void initState() {
    super.initState();
    _pastTests = [
      {'title': 'Algebra Témazáró I.', 'detail': '5'},
      {'title': 'Számelmélet Dolgozat', 'detail': '4'},
      {'title': 'Félévi Felmérő', 'detail': '-'},
    ];
    _fetchMembers();

    // Init customize state
    _groupNameController = TextEditingController(text: widget.group.title);
    _selectedColor = widget.group.color;
    final hsl = HSLColor.fromColor(_selectedColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _lightness = hsl.lightness;

    // Initialize invite code
    _currentInviteCode =
        widget.group.inviteCodeFormatted ?? widget.group.inviteCode;
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

  @override
  void didUpdateWidget(GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.hasNotification &&
        !widget.group.hasNotification &&
        oldWidget.group.activeTestTitle != null) {
      setState(() {
        _pastTests.insert(0, {
          'title': oldWidget.group.activeTestTitle!,
          'detail': '-',
        });
      });
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
                  child: Container(color: Colors.black.withOpacity(0.5)),
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
                          .withOpacity(0.9),
                      fontSize: isMobile ? 13 : 18,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  // Gombok
                  if (isMobile)
                    // Mobil nézet: csak ikonok
                    Row(
                      children: [
                        if (widget.group.rank == 'ADMIN')
                          _buildIconButton(
                            icon: Icons.settings,
                            tooltip: 'Beállítások',
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
                          _buildIconButton(
                            icon: Icons.exit_to_app,
                            tooltip: 'Csoport elhagyása',
                            onPressed: () =>
                                _showLeaveGroupConfirmation(context),
                          ),
                        const SizedBox(width: 8),
                        _buildIconButton(
                          icon: Icons.people_outline,
                          tooltip: 'Tagok',
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
                                    .withOpacity(0.7),
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
                                    .withOpacity(0.7),
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
                                  .withOpacity(0.7),
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

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.group.getTextColor(context).withOpacity(0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: widget.group.getTextColor(context),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildTestContent() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        if (widget.group.hasNotification &&
            widget.group.testExpiryDate != null) ...[
          _buildActiveTestCard(),
          const SizedBox(height: 24),
        ],
        const HeaderWithDivider(title: 'Jövőbeli tesztek'),
        const SizedBox(height: 16),
        _buildTestCard(
          title: 'Algebra Témazáró II.',
          detail: '2025. nov. 28.',
          isGrade: false,
        ),
        _buildTestCard(
          title: 'Geometria Röpdolgozat',
          detail: '2025. dec. 05.',
          isGrade: false,
        ),
        const SizedBox(height: 24),
        const HeaderWithDivider(title: 'Múltbeli tesztek'),
        const SizedBox(height: 16),
        ..._pastTests.map((test) {
          final isNumeric = int.tryParse(test['detail']!) != null;
          return _buildTestCard(
            title: test['title']!,
            detail: test['detail']!,
            isGrade: isNumeric,
          );
        }).toList(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTestCard({
    required String title,
    required String detail,
    required bool isGrade,
  }) {
    final theme = Theme.of(context);
    return Container(
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
            child: Text(
              title,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              softWrap: true,
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
    );
  }

  Widget _buildActiveTestCard() {
    final isExpired = widget.group.testExpiryDate!.isBefore(DateTime.now());
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 350;
        final horizontalPadding = constraints.maxWidth * 0.05;
        final responsivePadding = horizontalPadding.clamp(16.0, 24.0);

        return Card(
          color: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  responsivePadding,
                  20,
                  responsivePadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.hourglass_bottom,
                          color: Colors.yellow,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Jelenleg aktív teszt',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: isNarrow ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: theme.dividerColor, height: 24),
                    if (isNarrow)
                      // Narrow layout: stack content vertically
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.activeTestTitle ?? 'Nincs cím',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.group.activeTestDescription ??
                                'Nincs leírása a tesztnek.',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Készítő: ${widget.group.subtitle}',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.group.testExpiryDate != null) ...[
                            const SizedBox(height: 16),
                            CountdownTimerWidget(
                              expiryDate: widget.group.testExpiryDate!,
                              onExpired: () =>
                                  widget.onTestExpired(widget.group),
                            ),
                          ],
                        ],
                      )
                    else
                      // Wide layout: side-by-side with timer
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.group.activeTestTitle ?? 'Nincs cím',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.group.activeTestDescription ??
                                      'Nincs leírása a tesztnek.',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Készítő: ${widget.group.subtitle}',
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (widget.group.testExpiryDate != null)
                            CountdownTimerWidget(
                              expiryDate: widget.group.testExpiryDate!,
                              onExpired: () =>
                                  widget.onTestExpired(widget.group),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isExpired ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired
                      ? theme.disabledColor
                      : theme.primaryColor.withOpacity(0.2),
                  foregroundColor: isExpired
                      ? theme.disabledColor.withOpacity(0.5)
                      : theme.primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  disabledBackgroundColor: theme.disabledColor,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Teszt indítása',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.play_arrow, size: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String userName,
    int userId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tag eltávolítása: $userName'),
          content: Text(
            'Biztosan el akarod távolítani $userName-t a csoportból?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégsem'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeMember(userId);
              },
              child: const Text(
                'Eltávolítás',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
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
    final success = await apiService.removeMember(
      token,
      widget.group.id!,
      userId,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tag sikeresen eltávolítva'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchMembers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba a tag eltávolításakor'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoadingMembers = false);
    }
  }

  void _showAdminTransferConfirmation(
    BuildContext context,
    String userName,
    int userId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Admin jog átadása: $userName'),
          content: Text(
            'Biztosan átadod az admin jogot $userName-nak? Ezzel elveszíted a csoport feletti adminisztrátori jogodat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégsem'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _transferAdmin(userId);
              },
              child: const Text(
                'Átadás',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Csoport Törlése',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biztosan törölni szeretnéd a "${widget.group.title}" csoportot?',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ez a művelet nem vonható vissza! A csoport és minden tagsága törlésre kerül.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Jelszó megerősítés',
                      hintText: 'Add meg a jelszavadat',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          passwordController.dispose();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Mégsem'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kérlek add meg a jelszavadat!'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isLoading = true);

                          final success = await _deleteGroup(
                            passwordController.text,
                          );

                          if (!mounted) return;
                          passwordController.dispose();
                          Navigator.of(dialogContext).pop();

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Csoport sikeresen törölve'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            widget.onGroupLeft?.call();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Hiba a csoport törlésekor. Ellenőrizd a jelszót!',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Törlés'),
                ),
              ],
            );
          },
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Csoport elhagyása'),
          content: Text(
            'Biztosan elhagyod a "${widget.group.title}" csoportot?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégsem'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _leaveGroup();
              },
              child: const Text(
                'Elhagyás',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
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

    final colorHex = _selectedColor.value
        .toRadixString(16)
        .substring(2)
        .toUpperCase();

    final success = await ApiService().updateGroup(
      token,
      widget.group.id!,
      name: _groupNameController.text,
      color: '#$colorHex',
      anticheat: _antiCheat,
      kiosk: _kioskMode,
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
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.5 : 0.1,
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
                      color: theme.iconTheme.color?.withOpacity(0.7),
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
                  _buildSettingTile(
                    theme: theme,
                    title: 'Kiosk Mód',
                    subtitle: 'Teljes képernyős mód',
                    value: _kioskMode,
                    onChanged: (val) => setState(() => _kioskMode = val),
                    icon: Icons.fullscreen,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingTile(
                    theme: theme,
                    title: 'Anti Cheat',
                    subtitle: 'Csalásmegelőzés',
                    value: _antiCheat,
                    onChanged: (val) => setState(() => _antiCheat = val),
                    icon: Icons.security,
                  ),
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
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
      prefixIcon: Icon(icon, color: theme.iconTheme.color?.withOpacity(0.6)),
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
              overlayColor: Colors.white.withOpacity(0.2),
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

  Widget _buildSettingTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        trailing: Switch(
          value: value,
          activeColor: theme.primaryColor,
          onChanged: onChanged,
        ),
      ),
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
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.5 : 0.1,
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
                      color: theme.iconTheme.color?.withOpacity(0.7),
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
                            color: theme.iconTheme.color?.withOpacity(0.5),
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
      color: color.withOpacity(0.15),
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
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
        color: theme.cardColor.withOpacity(0.5),
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                        color: theme.iconTheme.color?.withOpacity(0.7),
                      ),
                      tooltip: 'Új kód generálása',
                      onPressed: _regenerateInviteCode,
                    ),
              IconButton(
                icon: Icon(
                  Icons.copy_outlined,
                  color: theme.iconTheme.color?.withOpacity(0.7),
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
          color: Colors.black.withOpacity(0.25),
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
