// lib/screens/stats/my_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../api_service.dart';
import '../../providers/user_provider.dart';
import '../../models/stats_models.dart';
import 'widgets/stats_widgets.dart';
import 'quiz_detail_screen.dart';
import 'group_detail_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  List<GroupWithRankOutSchema> _groups = [];
  List<SubmissionOutSchema> _allSubmissions = [];
  List<Map<String, dynamic>> _groupPerformance = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    try {
      // Parallel fetch for speed
      final results = await Future.wait([
        _api.getMe(token),
        _api.getGroupsWithRank(token),
      ]);

      _user = results[0] as Map<String, dynamic>?;
      _groups = results[1] as List<GroupWithRankOutSchema>;

      // Fetch results for each group
      final List<SubmissionOutSchema> allSubmissions = [];
      final List<Map<String, dynamic>> performance = [];

      for (var group in _groups) {
        final submissions = await _api.getStudentResults(token, group.id);
        allSubmissions.addAll(submissions);

        if (submissions.isNotEmpty) {
          final avg = submissions.map((s) => s.percentage).reduce((a, b) => a + b) / submissions.length;
          performance.add({
            'id': group.id,
            'name': group.name,
            'color': group.color,
            'avg': avg,
          });
        }
      }

      setState(() {
        _allSubmissions = allSubmissions;
        _groupPerformance = performance;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba az adatok betöltésekor: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil és Statisztika'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildContent(theme),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.3),
          highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Container(
            height: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          ),
        ),
        const SizedBox(height: 32),
        Shimmer.fromColors(
          baseColor: Colors.grey.withValues(alpha: 0.3),
          highlightColor: Colors.grey.withValues(alpha: 0.1),
          child: Container(height: 20, width: 150, color: Colors.white),
        ),
        const SizedBox(height: 16),
        ...List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.withValues(alpha: 0.3),
            highlightColor: Colors.grey.withValues(alpha: 0.1),
            child: Container(height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
          ),
        )),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_user == null) return const Center(child: Text('Nem sikerült betölteni a profilt.'));

    final avgPct = _allSubmissions.isEmpty
        ? 0.0
        : _allSubmissions.map((s) => s.percentage).reduce((a, b) => a + b) / _allSubmissions.length;
    
    final maxPct = _allSubmissions.isEmpty
        ? 0.0
        : _allSubmissions.map((s) => s.percentage).reduce((a, b) => a > b ? a : b);

    final adminCount = _groups.where((g) => g.rank == 'ADMIN').length;
    final memberCount = _groups.where((g) => g.rank == 'MEMBER').length;

    // Sort submissions by date
    final recentSubmissions = List<SubmissionOutSchema>.from(_allSubmissions);
    recentSubmissions.sort((a, b) => (b.submittedAt ?? DateTime(0)).compareTo(a.submittedAt ?? DateTime(0)));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PersonalSummaryCard(
            user: _user!,
            totalSubmissions: _allSubmissions.length,
            averagePercentage: avgPct,
            maxPercentage: maxPct,
            adminGroups: adminCount,
            memberGroups: memberCount,
          ),
          const SizedBox(height: 32),
          if (_groupPerformance.isNotEmpty) ...[
            AllGroupsPerformanceChart(
              groupPerformance: _groupPerformance,
              onGroupTap: (data) {
                final group = _groups.firstWhere((g) => g.id == data['id']);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDetailScreen(
                      group: group,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          const Text(
            'Legutóbbi eredmények',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (recentSubmissions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Text('Még nincs eredményed.', style: TextStyle(color: theme.hintColor)),
              ),
            )
          else
            ...recentSubmissions.take(5).map((s) {
              final groupName = _findGroupNameForResult(s);
              
              return RecentSubmissionRow(
                submission: s,
                groupName: groupName,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizDetailStatsScreen(
                        quizId: s.quizId ?? 0,
                        quizTitle: s.quizTitle,
                        role: _groups.any((g) => g.id == _findGroupIdForResult(s) && g.rank == 'ADMIN') ? 'ADMIN' : 'MEMBER',
                        submissionId: s.id,
                      ),
                    ),
                  );
                },
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _findGroupNameForResult(SubmissionOutSchema s) {
    if (_groups.any((g) => g.id == _findGroupIdForResult(s))) {
      return _groups.firstWhere((g) => g.id == _findGroupIdForResult(s)).name;
    }
    return 'Csoport';
  }

  int _findGroupIdForResult(SubmissionOutSchema s) {
    return s.quizId ?? 0; 
  }
}
