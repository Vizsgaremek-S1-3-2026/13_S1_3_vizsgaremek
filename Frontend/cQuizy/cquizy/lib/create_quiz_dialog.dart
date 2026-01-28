import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

class CreateQuizDialog extends StatefulWidget {
  final int groupId;
  final Map<String, dynamic>? existingQuiz;

  const CreateQuizDialog({super.key, required this.groupId, this.existingQuiz});

  @override
  State<CreateQuizDialog> createState() => _CreateQuizDialogState();
}

class _CreateQuizDialogState extends State<CreateQuizDialog> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _projects = [];
  Map<String, dynamic>? _selectedProject;

  // Date selection
  late DateTime _startDate;
  late DateTime _endDate;
  final DateFormat _dateFormat = DateFormat('yyyy. MM. dd. HH:mm');

  bool get _isEditing => widget.existingQuiz != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _startDate = DateTime.parse(widget.existingQuiz!['date_start']).toLocal();
      _endDate = DateTime.parse(widget.existingQuiz!['date_end']).toLocal();
      // We don't strictly need to fetch projects if editing, as project is fixed
      // But we might want to show the project name.
      // For now, let's just initialize dates.
    } else {
      final now = DateTime.now();
      _startDate = now;
      _endDate = now.add(const Duration(minutes: 45)); // Default 45 mins
      _fetchProjects();
    }
  }

  Future<void> _fetchProjects() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();
    try {
      final projects = await api.getProjects(token);
      if (mounted) {
        setState(() {
          _projects = projects;
          // Pre-select if only one
          if (_projects.length == 1) {
            _selectedProject = _projects.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? _startDate : _endDate;

    // Pick Date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(
        const Duration(days: 365),
      ), // Allow past dates for editing
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
              onSurface: Theme.of(context).textTheme.bodyLarge!.color!,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    // Pick Time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).cardColor,
              hourMinuteColor: Theme.of(context).primaryColor.withOpacity(0.2),
              hourMinuteTextColor: Theme.of(context).primaryColor,
              dayPeriodTextColor: Theme.of(context).textTheme.bodyMedium?.color,
              dialHandColor: Theme.of(context).primaryColor,
              dialBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startDate = newDateTime;
        // Adjust end date if it's before start
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(minutes: 45));
        }
      } else {
        _endDate = newDateTime;
      }
    });
  }

  Future<void> _save() async {
    if (!_isEditing && _selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Válassz egy projektet!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A befejezés nem lehet korábban, mint a kezdés!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;

    if (token != null) {
      final api = ApiService();
      Map<String, dynamic>? result;

      if (_isEditing) {
        result = await api.updateQuiz(
          token,
          widget.existingQuiz!['id'],
          _startDate.toUtc(),
          _endDate.toUtc(),
        );
      } else {
        result = await api.createQuiz(
          token,
          _selectedProject!['id'],
          widget.groupId,
          _startDate.toUtc(),
          _endDate.toUtc(),
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null) {
          Navigator.pop(context, true); // Return true for success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Hiba a teszt módosítása során'
                    : 'Hiba a teszt létrehozása során',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sort projects
    _projects.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

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
                      Icons.assignment_add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Teszt szerkesztése' : 'Új teszt kiírása',
                      style: const TextStyle(
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing) ...[
                    // Project Dropdown
                    Text(
                      'Projekt kiválasztása',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.scaffoldBackgroundColor,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _selectedProject,
                          isExpanded: true,
                          hint: Text(
                            'Válassz projektet...',
                            style: TextStyle(color: theme.hintColor),
                          ),
                          dropdownColor: theme.cardColor,
                          items: _projects.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                p['name'] ?? 'Névtelen',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProject = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Projekt: ${widget.existingQuiz!['project_name'] ?? 'Ismeretlen'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Date Pickers
                  Text(
                    'Időtartam beállítása',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          context,
                          label: 'Kezdés',
                          date: _startDate,
                          onTap: () => _pickDateTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward,
                        color: theme.hintColor,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateButton(
                          context,
                          label: 'Befejezés',
                          date: _endDate,
                          onTap: () => _pickDateTime(false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
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
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: theme.primaryColor.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Mentés' : 'Létrehozás',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }

  Widget _buildDateButton(
    BuildContext context, {
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
          color: theme.scaffoldBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(
              _dateFormat.format(date),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
