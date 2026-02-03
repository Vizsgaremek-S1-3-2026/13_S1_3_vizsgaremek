import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'project_editor_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  int? _expandedProjectId;
  String _sortBy =
      'name_asc'; // 'name_asc', 'name_desc', 'date_asc', 'date_desc'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Hungarian collation: normalize accented characters for proper sorting
  String _hungarianNormalize(String s) {
    return s
        .toLowerCase()
        .replaceAll('á', 'a\u0001')
        .replaceAll('é', 'e\u0001')
        .replaceAll('í', 'i\u0001')
        .replaceAll('ó', 'o\u0001')
        .replaceAll('ö', 'o\u0002')
        .replaceAll('ő', 'o\u0003')
        .replaceAll('ú', 'u\u0001')
        .replaceAll('ü', 'u\u0002')
        .replaceAll('ű', 'u\u0003');
  }

  List<Map<String, dynamic>> get _sortedProjects {
    // First filter by search query
    var filtered = _projects;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = _projects.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['desc'] ?? '').toString().toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }

    // Then sort
    final sorted = List<Map<String, dynamic>>.from(filtered);
    switch (_sortBy) {
      case 'name_asc':
        sorted.sort(
          (a, b) => _hungarianNormalize(
            (a['name'] ?? '').toString(),
          ).compareTo(_hungarianNormalize((b['name'] ?? '').toString())),
        );
        break;
      case 'name_desc':
        sorted.sort(
          (a, b) => _hungarianNormalize(
            (b['name'] ?? '').toString(),
          ).compareTo(_hungarianNormalize((a['name'] ?? '').toString())),
        );
        break;
      case 'date_asc':
        sorted.sort(
          (a, b) => (a['date_created'] ?? '').toString().compareTo(
            (b['date_created'] ?? '').toString(),
          ),
        );
        break;
      case 'date_desc':
        sorted.sort(
          (a, b) => (b['date_created'] ?? '').toString().compareTo(
            (a['date_created'] ?? '').toString(),
          ),
        );
        break;
    }
    return sorted;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    _fetchProjects();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSort = prefs.getString('projects_sort_by');
    if (savedSort != null && mounted) {
      setState(() => _sortBy = savedSort);
    }
  }

  Future<void> _saveSortPreference(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects_sort_by', value);
  }

  Future<void> _fetchProjects() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();
    final projects = await api.getProjects(token);

    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProject(int projectId, String name) async {
    final theme = Theme.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade700, Colors.red.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Projekt törlése',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Biztosan törölni szeretnéd a "$name" projektet? Ez a művelet nem vonható vissza.',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 15,
                  ),
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Mégse',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Törlés'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete == true) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;
      if (token == null) return;

      final api = ApiService();
      final success = await api.deleteProject(token, projectId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Projekt sikeresen törölve!'),
              backgroundColor: Colors.green.shade600,
            ),
          );
          _fetchProjects();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hiba a projekt törlésekor'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateProject(Map<String, dynamic> project) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();

    // Create a new project with copied name and description
    final newName = '${project['name']} (másolat)';
    final newDesc = project['desc'] ?? '';

    final newProject = await api.createProject(token, newName, newDesc);

    if (newProject == null || !mounted) return;

    final newProjectId = newProject['id'];

    // Get original project details to copy blocks
    final originalDetails = await api.getProjectDetails(token, project['id']);
    if (originalDetails == null) return;

    // Copy blocks to new project
    final blocks = originalDetails['blocks'] as List? ?? [];
    if (blocks.isNotEmpty) {
      final cleanedBlocks = blocks.map((b) {
        final block = Map<String, dynamic>.from(b);
        block['id'] = 0; // Reset ID for new block
        block.remove('order');

        final answers = List<Map<String, dynamic>>.from(block['answers'] ?? []);
        block['answers'] = answers.map((a) {
          final answer = Map<String, dynamic>.from(a);
          answer['id'] = 0; // Reset ID for new answer
          return answer;
        }).toList();

        return block;
      }).toList();

      await api.updateProject(token, newProjectId, {
        'name': newName,
        'desc': newDesc,
        'blocks': cleanedBlocks,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Projekt sikeresen duplikálva!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      _fetchProjects();
    }
  }

  Future<void> _exportProject(Map<String, dynamic> project) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    try {
      final api = ApiService();
      // Fetch full details including blocks
      final fullProject = await api.getProjectDetails(token, project['id']);
      if (fullProject == null) {
        throw Exception('Nem sikerült betölteni a projekt adatait.');
      }

      final Map<String, dynamic> projectData = {
        'name': fullProject['name'],
        'desc': fullProject['desc'],
        'blocks': fullProject['blocks'] ?? [],
      };

      final String jsonString = jsonEncode(projectData);
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Projekt exportálása',
        fileName:
            '${(fullProject['name'] as String).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.cq',
        allowedExtensions: ['cq'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        // Enforce extension
        if (!outputFile.endsWith('.cq')) {
          outputFile += '.cq';
        }
        final File file = File(outputFile);
        await file.writeAsString(jsonString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Projekt sikeresen exportálva!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba az exportálás során: $e'),
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
            _fetchProjects();
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

  Widget _buildInlineActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(isDark ? 0.2 : 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _fetchProjects,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0.0),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          children: [
            // Header title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Projektek',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color?.withOpacity(
                        0.8,
                      ),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.upload_file, color: theme.primaryColor),
                    tooltip: 'Projekt importálása',
                    onPressed: _importProject,
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
            // Search field and sort dropdown in same row
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
                            value: 'name_asc',
                            child: Text('Név (A-Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'name_desc',
                            child: Text('Név (Z-A)'),
                          ),
                          DropdownMenuItem(
                            value: 'date_desc',
                            child: Text('Legújabb'),
                          ),
                          DropdownMenuItem(
                            value: 'date_asc',
                            child: Text('Legrégebbi'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                            _saveSortPreference(value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(height: 1, color: theme.dividerColor),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              Center(
                child: LoadingAnimationWidget.newtonCradle(
                  color: theme.primaryColor,
                  size: 80,
                ),
              )
            else if (_projects.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_outlined,
                      size: 80,
                      color: theme.colorScheme.onBackground.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Jelenleg nincsenek projektek',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onBackground.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._sortedProjects.map((project) {
                final name = project['name'] ?? 'Névtelen';
                final desc = project['desc'] ?? '';
                final isMobile = MediaQuery.of(context).size.width < 600;
                final projectId = project['id'];
                final isExpanded = _expandedProjectId == projectId;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  constraints: const BoxConstraints(),
                  margin: EdgeInsets.only(
                    bottom: isMobile ? 12.0 : 16.0,
                    left: isMobile ? 12.0 : 16.0,
                    right: isMobile ? 12.0 : 16.0,
                  ),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [Colors.grey[800]!, Colors.grey[900]!]
                          : [Colors.grey[300]!, Colors.grey[400]!],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isExpanded ? 0.2 : 0.1),
                        blurRadius: isExpanded ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main row
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (projectId != null) {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ProjectEditorPage(
                                    projectId: projectId,
                                    initialName: name,
                                    initialDesc: desc,
                                  ),
                                ),
                              );
                              _fetchProjects();
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _expandedProjectId = isExpanded
                                  ? null
                                  : projectId;
                            });
                          },
                          onSecondaryTap: () {
                            setState(() {
                              _expandedProjectId = isExpanded
                                  ? null
                                  : projectId;
                            });
                          },
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(8),
                            bottom: Radius.circular(isExpanded ? 0 : 8),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 20.0 : 40.0,
                              vertical: isMobile ? 14.0 : 20.0,
                            ),
                            child: Row(
                              children: [
                                // Project info
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: isMobile ? 18 : 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (desc.isNotEmpty) ...[
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(
                                          desc,
                                          style: TextStyle(
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black87)
                                                    .withOpacity(0.8),
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Menu toggle button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _expandedProjectId = isExpanded
                                          ? null
                                          : projectId;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: AnimatedRotation(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      turns: isExpanded ? 0.25 : 0,
                                      child: Icon(
                                        Icons.more_vert,
                                        color:
                                            (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                .withOpacity(0.6),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Expandable action buttons
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Row(
                            children: [
                              // Edit button
                              Expanded(
                                child: _buildInlineActionButton(
                                  icon: Icons.edit,
                                  label: 'Szerkesztés',
                                  color: theme.primaryColor,
                                  isDark: isDark,
                                  onTap: () async {
                                    setState(() => _expandedProjectId = null);
                                    if (projectId != null) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ProjectEditorPage(
                                                projectId: projectId,
                                                initialName: name,
                                                initialDesc: desc,
                                              ),
                                        ),
                                      );
                                      _fetchProjects();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Duplicate button
                              Expanded(
                                child: _buildInlineActionButton(
                                  icon: Icons.copy,
                                  label: 'Duplikálás',
                                  color: Colors.teal,
                                  isDark: isDark,
                                  onTap: () {
                                    setState(() => _expandedProjectId = null);
                                    _duplicateProject(project);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Export button
                              Expanded(
                                child: _buildInlineActionButton(
                                  icon: Icons.download,
                                  label: 'Export',
                                  color: Colors.blueAccent,
                                  isDark: isDark,
                                  onTap: () {
                                    setState(() => _expandedProjectId = null);
                                    _exportProject(project);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              Expanded(
                                child: _buildInlineActionButton(
                                  icon: Icons.delete,
                                  label: 'Törlés',
                                  color: Colors.red,
                                  isDark: isDark,
                                  onTap: () {
                                    setState(() => _expandedProjectId = null);
                                    _deleteProject(projectId, name);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
