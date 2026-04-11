// lib/screens/stats/quiz_detail_screen.dart

import 'package:flutter/material.dart';
import 'quiz_admin_stats.dart';
import 'quiz_student_result.dart';

class QuizDetailStatsScreen extends StatelessWidget {
  final int quizId;
  final String quizTitle;
  final String role; // 'ADMIN' or 'MEMBER'
  final int? submissionId; // For student view

  const QuizDetailStatsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.role,
    this.submissionId,
  });

  @override
  Widget build(BuildContext context) {
    if (role == 'ADMIN') {
      return QuizAdminStats(quizId: quizId, quizTitle: quizTitle);
    } else {
      return QuizStudentResult(quizId: quizId, quizTitle: quizTitle, submissionId: submissionId);
    }
  }
}
