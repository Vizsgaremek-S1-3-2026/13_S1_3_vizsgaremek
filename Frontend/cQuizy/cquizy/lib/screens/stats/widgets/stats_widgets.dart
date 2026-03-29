// lib/screens/stats/widgets/stats_widgets.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../models/stats_models.dart';

class PersonalSummaryCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int totalSubmissions;
  final double averagePercentage;
  final double maxPercentage;
  final int adminGroups;
  final int memberGroups;

  const PersonalSummaryCard({
    super.key,
    required this.user,
    required this.totalSubmissions,
    required this.averagePercentage,
    required this.maxPercentage,
    required this.adminGroups,
    required this.memberGroups,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pfpUrl = user['pfp_url']?.toString();
    final name = '${user['last_name'] ?? ''} ${user['first_name'] ?? ''}'.trim();
    final username = user['username']?.toString() ?? 'N/A';
    final dateJoined = user['date_joined'] != null 
        ? DateFormat('yyyy. MM. dd.').format(DateTime.parse(user['date_joined']))
        : 'Ismeretlen';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white24,
                backgroundImage: pfpUrl != null ? CachedNetworkImageProvider(pfpUrl) : null,
                child: pfpUrl == null 
                    ? const Icon(Icons.person, color: Colors.white, size: 40) 
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@$username • Tag: $dateJoined',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Beadások', '$totalSubmissions'),
              _buildStatItem('Átlag', '${averagePercentage.toStringAsFixed(1)}%'),
              _buildStatItem('Rekord', '${maxPercentage.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('Admin: $adminGroups', Icons.admin_panel_settings),
              const SizedBox(width: 12),
              _buildBadge('Tag: $memberGroups', Icons.group),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AllGroupsPerformanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> groupPerformance;
  final Function(Map<String, dynamic>)? onGroupTap;

  const AllGroupsPerformanceChart({
    super.key, 
    required this.groupPerformance,
    this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredGroups = groupPerformance.where((g) => g['avg'] > 0).toList();
    
    if (filteredGroups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Csoportos teljesítmény',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...filteredGroups.map((group) {
          final colorStr = group['color']?.toString() ?? '4285F4';
          final color = _parseColor(colorStr);
          final avg = group['avg'] as double;

          return InkWell(
            onTap: onGroupTap != null ? () => onGroupTap!(group) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group['name']?.toString() ?? 'Csoport',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        '${avg.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        height: 8,
                        width: MediaQuery.of(context).size.width * (avg / 100) * 0.8, // Adjusted for padding
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) colorStr = colorStr.substring(1);
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }
}

class RecentSubmissionRow extends StatelessWidget {
  final SubmissionOutSchema submission;
  final String groupName;
  final VoidCallback? onTap;

  const RecentSubmissionRow({
    super.key,
    required this.submission,
    required this.groupName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = submission.submittedAt != null 
        ? DateFormat('MM. dd. HH:mm').format(submission.submittedAt!)
        : '–';
    
    final color = _getGradeColor(submission.percentage);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  submission.gradeValue ?? '–',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.quizTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$groupName • $date',
                    style: TextStyle(color: theme.hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${submission.percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Icon(Icons.chevron_right, size: 16, color: theme.hintColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(double pct) {
    if (pct >= 85) return Colors.green;
    if (pct >= 70) return Colors.blue;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }
}
