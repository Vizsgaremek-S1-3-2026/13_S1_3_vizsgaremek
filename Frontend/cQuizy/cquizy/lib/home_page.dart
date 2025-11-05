// lib/home_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'group_page.dart';

// A Group modell változatlan
class Group {
  final String title;
  final String subtitle;
  final Gradient gradient;
  final bool hasNotification;
  final DateTime? testExpiryDate;
  final String? activeTestTitle;
  final String? activeTestDescription;

  Group({
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.hasNotification = false,
    this.testExpiryDate,
    this.activeTestTitle,
    this.activeTestDescription,
  });

  Group copyWith({
    String? title,
    String? subtitle,
    Gradient? gradient,
    bool? hasNotification,
    DateTime? testExpiryDate,
    String? activeTestTitle,
    String? activeTestDescription,
  }) {
    return Group(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      gradient: gradient ?? this.gradient,
      hasNotification: hasNotification ?? this.hasNotification,
      testExpiryDate: testExpiryDate ?? this.testExpiryDate,
      activeTestTitle: activeTestTitle ?? this.activeTestTitle,
      activeTestDescription:
          activeTestDescription ?? this.activeTestDescription,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Group> _myGroups;
  late List<Group> _otherGroups;
  late List<Group> _activeTests;
  Group? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
  }

  List<Group> _getActiveTests() {
    return [..._myGroups, ..._otherGroups]
        .where((group) =>
            group.hasNotification &&
            group.testExpiryDate != null &&
            group.testExpiryDate!.isAfter(DateTime.now()))
        .toList();
  }

  void _initializeGroups() {
    _myGroups = [
      Group(
        title: 'Matematika 8.A',
        subtitle: 'Toszt Elek',
        gradient: const LinearGradient(
          colors: [Color(0xff6a1b2d), Color(0xffb72c31)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    ];
    _otherGroups = [
      Group(
        title: 'Földrajz 7.C',
        subtitle: 'Csillagos Klára',
        gradient: const LinearGradient(
          colors: [Color(0xff9e6a18), Color(0xffd49c2e)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        hasNotification: false,
      ),
      Group(
        title: 'Programozás alapjai 10.A',
        subtitle: 'Kód Elek',
        gradient: const LinearGradient(
          colors: [Color(0xff6d2c77), Color(0xffa142ad)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        hasNotification: true,
        testExpiryDate:
            DateTime.now().add(const Duration(seconds: 15)), // Teszteléshez rövid idő
        activeTestTitle: 'Algoritmusok I. Témazáró',
        activeTestDescription:
            'Ez a teszt a tanév első felében tanult alapvető algoritmusokat (sorbarendezés, keresés) kéri számon. A teszt 45 perces.',
      ),
      Group(
          title: 'Angol Haladó 11.B',
          subtitle: 'Fordító Ágnes',
          gradient: const LinearGradient(
              colors: [Color(0xff1a7a6a), Color(0xff2cb39a)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          hasNotification: true,
          testExpiryDate: DateTime.now().add(const Duration(hours: 8, minutes: 30)),
          activeTestTitle: 'Present Perfect Szódolgozat',
          activeTestDescription: 'Rövid, 10 perces szódolgozat a legutóbbi órán vett szavakból.'),
    ];

    _cleanupExpiredNotifications();
    _activeTests = _getActiveTests();
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
      int otherIndex =
          _otherGroups.indexWhere((g) => g.title == expiredGroup.title);
      if (otherIndex != -1) {
        _otherGroups[otherIndex] =
            _otherGroups[otherIndex].copyWith(hasNotification: false);
      } else {
        int myIndex =
            _myGroups.indexWhere((g) => g.title == expiredGroup.title);
        if (myIndex != -1) {
          _myGroups[myIndex] =
              _myGroups[myIndex].copyWith(hasNotification: false);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: Row(
        children: [
          _buildSideNav(_activeTests),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedGroup == null
                  ? _buildGroupList()
                  : GroupPage(
                      key: ValueKey(_selectedGroup!.title),
                      group: _selectedGroup!,
                      onBack: _unselectGroup,
                      onTestExpired: _handleTestExpired,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return ListView(
      key: const ValueKey('group_list'),
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: HeaderWithDivider(title: 'Saját Csoportok'),
        ),
        const SizedBox(height: 20),
        ..._myGroups
            .map((group) =>
                GroupCard(group: group, onGroupSelected: _selectGroup))
            .toList(),
        const SizedBox(height: 30),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.0),
          child: HeaderWithDivider(title: 'További Csoportok'),
        ),
        const SizedBox(height: 20),
        ..._otherGroups
            .map((group) =>
                GroupCard(group: group, onGroupSelected: _selectGroup))
            .toList(),
        const SizedBox(height: 80),
      ],
    );
  }

  // *** MÓDOSÍTOTT SIDE NAV ***
  Widget _buildSideNav(List<Group> activeTests) {
    return Container(
      width: 280,
      color: const Color(0xFF252525),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          SideNavItem(
            label: 'Csoportok',
            icon: Icons.group,
            isSelected: _selectedGroup == null,
            onTap: _selectedGroup != null ? _unselectGroup : null,
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
              Image.asset(
                'assets/logo/logo_2.png',
                height: 16, // Kisebb méret
              ),
              const SizedBox(width: 8),
              Text(
                'cQuizy',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Divider(color: Color.fromARGB(61, 255, 255, 255)),         
          const SizedBox(height: 10),

          if (activeTests.isNotEmpty)
            ActiveTestCarousel(
              key: ValueKey(activeTests.map((g) => g.title).join()),
              activeTests: activeTests,
              onExpired: _handleTestExpired,
            ),
          const SizedBox(height: 24),
          //const Divider(color: Colors.white24),         
          const SizedBox(height: 16),
          SideNavItem(label: 'Profil & Beállítások'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ... CountdownTimerWidget, ActiveTestCard, ActiveTestCarousel, GroupCard változatlan ...

// *** MÓDOSÍTOTT/JAVÍTOTT SIDE NAV ITEM WIDGET ***
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
    return Material(
      color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            // Ha nincs ikon, a tartalom középre kerül
            mainAxisAlignment: icon == null ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // Az ikon és a távtartó csak akkor jelenik meg, ha van ikon megadva
              if (icon != null) ...[
                CircleAvatar(
                  backgroundColor: const Color(0xFF4f4f4f),
                  radius: 18,
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A többi widget változatlanul következik...

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
      final formattedDate =
          DateFormat('yyyy. MMM d. HH:mm').format(widget.expiryDate);
      return Text(formattedDate,
          style: TextStyle(
              color: Colors.white,
              fontSize: widget.isBig ? 16 : 14,
              fontWeight: FontWeight.w500));
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
            Icon(Icons.timer_outlined,
                color: Colors.white, size: widget.isBig ? 20 : 16),
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
              gradient: widget.group.gradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '$subject Témazáró',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Teszt Indítása',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.play_arrow, size: 20, color: Colors.white),
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
      int nextPage =
          _currentPage < widget.activeTests.length - 1 ? _currentPage + 1 : 0;
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
        SizedBox(
          height: 185,
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
        ]
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
          width: MediaQuery.of(context).size.width,
          constraints: const BoxConstraints(maxHeight: double.infinity),
          margin: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
          decoration: BoxDecoration(
            gradient: group.gradient,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onGroupSelected(group),
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 14),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
      ],
    );
  }
}