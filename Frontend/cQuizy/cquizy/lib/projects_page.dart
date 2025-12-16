import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'project_editor_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _fetchProjects,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 0.0,
        ), // Padding moved to list items to match home_page
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: _HeaderWithDivider(title: 'Projektek'),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
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
              ..._projects.map((project) {
                final name = project['name'] ?? 'Névtelen';
                final desc = project['desc'] ?? '';
                final isMobile = MediaQuery.of(context).size.width < 600;

                return Container(
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
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final projectId = project['id'];
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
                              name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
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
                                      (isDark ? Colors.white : Colors.black87)
                                          .withOpacity(0.8),
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

class _HeaderWithDivider extends StatelessWidget {
  final String title;
  const _HeaderWithDivider({required this.title});
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
