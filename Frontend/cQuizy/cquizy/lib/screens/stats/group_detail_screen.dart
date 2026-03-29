// lib/screens/stats/group_detail_screen.dart

import 'package:flutter/material.dart';
import '../../models/stats_models.dart';
import 'admin_group_dashboard.dart';
import 'student_group_dashboard.dart';

class GroupDetailScreen extends StatelessWidget {
  final GroupWithRankOutSchema group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    // Role-based routing
    if (group.rank == 'ADMIN') {
      return AdminGroupDashboard(groupId: group.id, groupName: group.name);
    } else {
      return StudentGroupDashboard(groupId: group.id, groupName: group.name);
    }
  }
}
