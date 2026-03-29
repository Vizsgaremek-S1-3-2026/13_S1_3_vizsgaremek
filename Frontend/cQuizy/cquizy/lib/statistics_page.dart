// lib/statistics_page.dart

import 'package:flutter/material.dart';
import 'screens/stats/my_profile_screen.dart';

/// Entry point for the new modular statistics module.
/// This class maintains the name for backward compatibility with HomePage.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyProfileScreen();
  }
}
