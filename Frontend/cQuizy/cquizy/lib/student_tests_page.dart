import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'utils/web_protections.dart';
import 'test_taking_page.dart';
import 'admin_page.dart';
import 'models/stats_models.dart';
import 'group_page.dart';

class StudentTestsPage extends StatefulWidget {
  final Function(Group)? onGroupSelected;
  const StudentTestsPage({super.key, this.onGroupSelected});

  @override
  State<StudentTestsPage> createState() => _StudentTestsPageState();
}

class _StudentTestsPageState extends State<StudentTestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _pastTests = [];
  final List<Map<String, dynamic>> _activeTests = [];
  final List<Map<String, dynamic>> _futureTests = [];

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _selectedMonth; // Filter by month
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // Search and Sort state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'date_asc'; // Default sort

  // Store quiz results to show grades
  final Map<int, SubmissionOutSchema> _quizResults = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchStudentTests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentTests() async {
    setState(() {
      _isLoading = true;
    });

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final api = ApiService();
    try {
      // 1. Fetch user groups
      final groups = await api.getUserGroups(token);

      List<Map<String, dynamic>> allQuizzes = [];

      // 2. Fetch quizzes for each group
      for (var group in groups) {
        final groupId = group['id'];
        final groupName = group['name'];
        final quizzes = await api.getGroupQuizzes(token, groupId);

        // Enhance quiz data with group name
        for (var quiz in quizzes) {
          final enhancedQuiz = Map<String, dynamic>.from(quiz);
          enhancedQuiz['group_name'] = groupName;
          enhancedQuiz['group_id'] = groupId;
          enhancedQuiz['group_obj'] = group; // Store full group object
          allQuizzes.add(enhancedQuiz);
        }

        // Fetch user results for this group to show grades
        try {
          final results = await api.getStudentResults(token, groupId);
          for (var res in results) {
            if (res.quizId != null) {
              _quizResults[res.quizId!] = res;
            }
          }
        } catch (e) {
          debugPrint('Error fetching results for group $groupId: $e');
        }
      }

      // 3. Sort and Categorize
      final now = DateTime.now();
      _pastTests.clear();
      _activeTests.clear();
      _futureTests.clear();
      _events = {};

      for (var quiz in allQuizzes) {
        final startDate = DateTime.tryParse(
          quiz['date_start'] ?? '',
        )?.toLocal();
        final endDate = DateTime.tryParse(quiz['date_end'] ?? '')?.toLocal();

        if (startDate == null || endDate == null) continue;

        // Populate Calendar Events
        // Iterate from start date to end date
        // Create a loop that goes day by day
        DateTime currentDay = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final endingDay = DateTime(endDate.year, endDate.month, endDate.day);

        // Safety check to prevent infinite loops if dates are weird (though api shouldn't allow)
        // Limit to e.g. 365 days max span to be safe
        int safetyCounter = 0;

        while ((currentDay.isBefore(endingDay) ||
                isSameDay(currentDay, endingDay)) &&
            safetyCounter < 366) {
          if (_events[currentDay] == null) _events[currentDay] = [];
          // Avoid duplicates if multiple iterations (e.g. if logic was different)
          // But here we create a new entry. checking if quiz is already there:
          if (!_events[currentDay]!.any((e) => e['id'] == quiz['id'])) {
            _events[currentDay]!.add(quiz);
          }

          currentDay = currentDay.add(const Duration(days: 1));
          safetyCounter++;
        }

        if (endDate.isBefore(now)) {
          _pastTests.add(quiz);
        } else if (startDate.isAfter(now)) {
          _futureTests.add(quiz);
        } else {
          _activeTests.add(quiz);
        }
      }

      // Sort lists
      // Past: most recent first
      _pastTests.sort((a, b) {
        final endA = DateTime.parse(a['date_end']);
        final endB = DateTime.parse(b['date_end']);
        return endB.compareTo(endA);
      });

      // Active: closing soonest first
      _activeTests.sort((a, b) {
        final endA = DateTime.parse(a['date_end']);
        final endB = DateTime.parse(b['date_end']);
        return endA.compareTo(endB);
      });

      // Future: opening soonest first
      _futureTests.sort((a, b) {
        final startA = DateTime.parse(a['date_start']);
        final startB = DateTime.parse(b['date_start']);
        return startA.compareTo(startB);
      });
    } catch (e) {
      debugPrint('Error fetching student tests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a tesztek betöltésekor: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Válassz hónapot',
    );

    if (picked != null) {
      setState(() {
        // Set to the first day of the picked month
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _clearMonthFilter() {
    setState(() {
      _selectedMonth = null;
    });
  }

  // Calendar Builder
  Widget _buildCalendar() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  return _events[DateTime(day.year, day.month, day.day)] ?? [];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tesztek ezen a napon:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildTestList(
              _events[DateTime(
                        _selectedDay!.year,
                        _selectedDay!.month,
                        _selectedDay!.day,
                      )]
                      ?.map((e) => Map<String, dynamic>.from(e))
                      .toList() ??
                  [],
              // We don't know strict status here without checking dates, but list handles it ok-ish
              // Or we can determine generic status. For now reusing list builder.
            ),
          ],
        ],
      ),
    );
  }

  void _showStartTestConfirmation(
    BuildContext context,
    Map<String, dynamic> quiz,
  ) {
    // Check for web restrictions first
    if (kIsWeb) {
      final group = quiz['group_obj'];
      final isLocked = group != null && (group['kiosk'] ?? false);

      if (isLocked) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Nem támogatott platform'),
            content: const Text(
              'Ez a teszt "Zárolt" módban van, ezért csak az asztali vagy mobil alkalmazásból indítható el.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Rendben'),
              ),
            ],
          ),
        );
        return;
      }
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
                                  WebProtections.enterFullScreen(); // Request browser fullscreen on user gesture
                                  Navigator.pop(context); // Close dialog

                                  // Prepare quiz object with group back-reference
                                  final group = quiz['group_obj'];
                                  // group might be null safely handled but it should be there
                                  final groupName =
                                      quiz['group_name'] ?? 'Unknown Group';
                                  final anticheat = group != null
                                      ? (group['anticheat'] ?? false)
                                      : false;
                                  final kiosk = group != null
                                      ? (group['kiosk'] ?? false)
                                      : false;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TestTakingPage(
                                        quiz: quiz,
                                        groupName: groupName,
                                        anticheat: anticheat,
                                        kiosk: kiosk,
                                      ),
                                    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header (Projektek style)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tesztek',
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
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

        // Search and Sort Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Keresés...',
                    prefixIcon: Icon(Icons.search, color: theme.hintColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: theme.hintColor),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    icon: Icon(
                      Icons.sort,
                      size: 18,
                      color: theme.iconTheme.color,
                    ),
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'date_asc',
                        child: Text('Lejárati dátum (Növ.)'),
                      ),
                      DropdownMenuItem(
                        value: 'date_desc',
                        child: Text('Lejárati dátum (Csökk.)'),
                      ),
                      DropdownMenuItem(
                        value: 'name_asc',
                        child: Text('Név (A-Z)'),
                      ),
                      DropdownMenuItem(
                        value: 'name_desc',
                        child: Text('Név (Z-A)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _sortBy = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Month Filter Button
              Container(
                decoration: BoxDecoration(
                  color: _selectedMonth != null
                      ? theme.primaryColor.withValues(alpha: 0.1)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedMonth != null
                        ? theme.primaryColor
                        : theme.dividerColor,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.calendar_month,
                    color: _selectedMonth != null
                        ? theme.primaryColor
                        : theme.iconTheme.color,
                  ),
                  tooltip: _selectedMonth != null
                      ? 'Szűrés törlése'
                      : 'Szűrés hónap szerint',
                  onPressed: _selectedMonth != null
                      ? _clearMonthFilter
                      : _pickMonth,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tab Bar
        Container(
          color: theme.scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            indicatorColor: theme.primaryColor,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(
              theme.primaryColor.withValues(alpha: 0.1),
            ),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Múltbeli'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Aktív'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.update_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Jövőbeli'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Naptár'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTestList(_applyFilters(_pastTests), isPast: true),
                    _buildTestList(_applyFilters(_activeTests), isActive: true),
                    _buildTestList(_applyFilters(_futureTests)),
                    _buildCalendar(),
                  ],
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> tests) {
    if (tests.isEmpty) return [];

    // Filter
    final filtered = tests.where((test) {
      // 1. Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (test['title'] ?? '').toString().toLowerCase();
        final group = (test['group_name'] ?? '').toString().toLowerCase();
        if (!title.contains(query) && !group.contains(query)) {
          return false;
        }
      }

      // 2. Month Filter
      if (_selectedMonth != null) {
        final testStart = DateTime.tryParse(test['date_start'] ?? '');
        if (testStart == null) return false;

        // Check if start date is in selected month
        if (testStart.year != _selectedMonth!.year ||
            testStart.month != _selectedMonth!.month) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      if (_sortBy == 'Dátum') {
        final dateA =
            DateTime.tryParse(a['date_start'] ?? '') ?? DateTime.now();
        final dateB =
            DateTime.tryParse(b['date_start'] ?? '') ?? DateTime.now();
        // Ascending or descending? Usually descending for dates in lists
        // But here let's stick to standard compare
        return dateB.compareTo(dateA); // Newest first
      } else if (_sortBy == 'Csoport') {
        final groupA = (a['group_name'] ?? '').toString();
        final groupB = (b['group_name'] ?? '').toString();
        return groupA.compareTo(groupB);
      }
      return 0;
    });

    return filtered;
  }

  Widget _buildTestList(
    List<Map<String, dynamic>> tests, {
    bool isPast = false,
    bool isActive = false,
  }) {
    if (tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nincs megjeleníthető teszt',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final quiz = tests[index];
        return _buildTestCard(quiz, isPast, isActive);
      },
    );
  }

  Widget _buildTestCard(Map<String, dynamic> quiz, bool isPast, bool isActive) {
    final theme = Theme.of(context);
    final startDate = DateTime.parse(quiz['date_start']).toLocal();
    final endDate = DateTime.parse(quiz['date_end']).toLocal();
    final dateFormat = DateFormat('yyyy. MM. dd. HH:mm');

    // Check if user is admin of the group
    final group = quiz['group_obj'];
    final isAdmin = group != null && group['rank'] == 'ADMIN';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isActive
            ? () {
                if (isAdmin) {
                  // If tapping card body, maybe also go to admin?
                  // Or just keep the button as the primary action.
                  // Current code had empty TODO.
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      quiz['project_name'] ?? 'Névtelen Teszt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'AKTÍV',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      quiz['group_name'] ?? 'Ismeretlen Csoport',
                      style: TextStyle(color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Group shortcut button
                  if (quiz['group_obj'] != null)
                    SizedBox(
                      height: 28,
                      child: TextButton(
                        onPressed: () {
                          if (widget.onGroupSelected != null) {
                            widget.onGroupSelected!(
                              Group.fromJson(quiz['group_obj']),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Csoport',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                ],
              ),
              if (isPast) ...[
                // Only show result if there is a grade
                if (_quizResults.containsKey(quiz['id']) &&
                    (_quizResults[quiz['id']]?.gradeValue?.isNotEmpty ??
                        false)) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Eredmény: ${_quizResults[quiz['id']]!.gradeValue} (${_quizResults[quiz['id']]!.percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Teacher Feedback Placeholder
                if (quiz['feedback'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.comment,
                              size: 16,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tanári visszajelzés:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quiz['feedback'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (isAdmin) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminPage(
                              quiz: quiz,
                              groupId: group?['id'] ?? quiz['group_id'],
                              groupName:
                                  group?['name'] ??
                                  quiz['group_name'] ??
                                  'Unknown',
                              grade2Limit: group?['grade2_limit'] ?? 40,
                              grade3Limit: group?['grade3_limit'] ?? 55,
                              grade4Limit: group?['grade4_limit'] ?? 70,
                              grade5Limit: group?['grade5_limit'] ?? 85,
                            ),
                          ),
                        );
                      } else {
                        _showStartTestConfirmation(context, quiz);
                      }
                    },
                    icon: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.play_arrow,
                    ),
                    label: Text(isAdmin ? 'Admin felület' : 'Kitöltés'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
