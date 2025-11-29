// lib/group_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // A vágólaphoz szükséges
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// --- MEOSZTOTT MODELL ---
class Group {
  final String title;
  final String subtitle;
  final Color color;
  final bool hasNotification;
  final DateTime? testExpiryDate;
  final String? activeTestTitle;
  final String? activeTestDescription;

  Group({
    required this.title,
    required this.subtitle,
    required this.color,
    this.hasNotification = false,
    this.testExpiryDate,
    this.activeTestTitle,
    this.activeTestDescription,
  });

  Group copyWith({
    String? title,
    String? subtitle,
    Color? color,
    bool? hasNotification,
    DateTime? testExpiryDate,
    String? activeTestTitle,
    String? activeTestDescription,
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

  const GroupPage({
    super.key,
    required this.group,
    required this.onTestExpired,
    this.onMemberPanelToggle,
  });

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMembersPanelVisible = false;
  late List<Map<String, String>> _pastTests;

  @override
  void initState() {
    super.initState();
    _pastTests = [
      {'title': 'Algebra Témazáró I.', 'detail': '5'},
      {'title': 'Számelmélet Dolgozat', 'detail': '4'},
      {'title': 'Félévi Felmérő', 'detail': '-'},
    ];
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
              if (_isMembersPanelVisible)
                GestureDetector(
                  onTap: () {
                    setState(() => _isMembersPanelVisible = false);
                    widget.onMemberPanelToggle?.call(false);
                  },
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              _buildMembersPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: widget.group.getGradient(context)),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.title,
                      style: TextStyle(
                        color: widget.group.getTextColor(context),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 2,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.black38
                                : Colors.white38,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Oktató: ${widget.group.subtitle}',
                      style: TextStyle(
                        color: widget.group
                            .getTextColor(context)
                            .withOpacity(0.9),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isMembersPanelVisible = !_isMembersPanelVisible;
                  });
                  widget.onMemberPanelToggle?.call(_isMembersPanelVisible);
                },
                icon: Icon(
                  Icons.people_outline,
                  color: widget.group.getTextColor(context),
                ),
                label: Text(
                  'Tagok',
                  style: TextStyle(color: widget.group.getTextColor(context)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: widget.group.getTextColor(context).withOpacity(0.7),
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

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String memberName,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tag törlése'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Biztosan törölni szeretnéd $memberName felhasználót?'),
                const Text('Ez a művelet nem vonható vissza.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Mégse'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Törlés', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$memberName törölve.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAdminTransferConfirmation(
    BuildContext context,
    String memberName,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Admin jog átadása'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Biztosan át szeretnéd adni az admin jogot $memberName felhasználónak?',
                ),
                const Text('Ezzel te elveszíted az admin jogosultságot.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Mégse'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Átadás'),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Admin jog átadva $memberName részére.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
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
                    'Csoport Tagjai (24)',
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
                      setState(() => _isMembersPanelVisible = false);
                      widget.onMemberPanelToggle?.call(false);
                    },
                  ),
                ],
              ),
            ),
            Divider(color: theme.dividerColor, height: 1),
            _buildInviteCodeCard(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                children: [
                  _buildSectionHeader('ADMIN'),
                  Divider(color: theme.dividerColor, height: 1),

                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFed2f5b),
                      child: Icon(Icons.star, color: Colors.white),
                    ),
                    title: Text(
                      'Admin Neve 1',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Admin',
                      style: TextStyle(color: Color(0xFFED2F5B)),
                    ),
                    trailing: const Icon(
                      Icons.workspace_premium, // Korona ikon
                      color: Color(0xFFed2f5b),
                    ),
                  ),
                  _buildSectionHeader('TAGOK (23)'),
                  Divider(color: theme.dividerColor, height: 1),

                  ...List.generate(23, (index) {
                    final memberIndex = index + 1;
                    return Slidable(
                      key: ValueKey(memberIndex),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        extentRatio: 0.6,
                        children: [
                          SlidableAction(
                            onPressed: (context) {
                              _showAdminTransferConfirmation(
                                context,
                                'Tag Neve $memberIndex',
                              );
                            },
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            icon: Icons.admin_panel_settings,
                            label: 'Admin',
                          ),
                          SlidableAction(
                            onPressed: (context) {
                              _showDeleteConfirmation(
                                context,
                                'Tag Neve $memberIndex',
                              );
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Törlés',
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          'Tag Neve $memberIndex',
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Text(
                          'Felhasználónév$memberIndex',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        trailing: Builder(
                          builder: (context) {
                            return IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                color: theme.iconTheme.color?.withOpacity(0.5),
                              ),
                              onPressed: () {
                                final slidable = Slidable.of(context);
                                slidable?.openEndActionPane();
                              },
                              tooltip: 'Műveletek',
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
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
    const inviteCode = 'X7B2-K9P5';
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
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: theme.iconTheme.color?.withOpacity(0.7),
                ),
                tooltip: 'Új kód generálása',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Új meghívókód generálása...'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_outlined,
                  color: theme.iconTheme.color?.withOpacity(0.7),
                ),
                tooltip: 'Kód másolása',
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: inviteCode));
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
