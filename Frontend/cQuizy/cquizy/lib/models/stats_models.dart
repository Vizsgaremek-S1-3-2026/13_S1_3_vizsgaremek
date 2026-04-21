// lib/models/stats_models.dart

import '../utils/avatar_manager.dart';

class AdminGroupOverviewSchema {
  final double averagePercentage;
  final String averageGradeLabel;
  final int totalStudents;
  final int totalQuizzes;

  AdminGroupOverviewSchema({
    required this.averagePercentage,
    required this.averageGradeLabel,
    required this.totalStudents,
    required this.totalQuizzes,
  });

  factory AdminGroupOverviewSchema.fromJson(Map<String, dynamic> json) {
    return AdminGroupOverviewSchema(
      averagePercentage: (json['avg_percentage'] as num?)?.toDouble() ?? 0.0,
      averageGradeLabel: json['avg_grade_label']?.toString() ?? 'N/A',
      totalStudents: json['total_students'] as int? ?? 0,
      totalQuizzes: json['total_quizzes'] as int? ?? 0,
    );
  }
}

class AdminStudentStatSchema {
  final int studentId;
  final String name;
  final double averagePercentage;
  final String grade;

  AdminStudentStatSchema({
    required this.studentId,
    required this.name,
    required this.averagePercentage,
    required this.grade,
  });

  factory AdminStudentStatSchema.fromJson(Map<String, dynamic> json) {
    return AdminStudentStatSchema(
      studentId: json['student_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Ismeretlen',
      averagePercentage: (json['avg_percentage'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade']?.toString() ?? '-',
    );
  }
}

class AdminQuizStatSchema {
  final int quizId;
  final String name;
  final DateTime? date;
  final double averagePercentage;
  final String grade;
  final int submissionCount;

  AdminQuizStatSchema({
    required this.quizId,
    required this.name,
    this.date,
    required this.averagePercentage,
    required this.grade,
    required this.submissionCount,
  });

  factory AdminQuizStatSchema.fromJson(Map<String, dynamic> json) {
    return AdminQuizStatSchema(
      quizId: json['quiz_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Kvíz',
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      averagePercentage: (json['avg_percentage'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade']?.toString() ?? '-',
      submissionCount: json['submission_count'] as int? ?? 0,
    );
  }
}

class GradePercentageSchema {
  final String name;
  final double minPercentage;
  final double maxPercentage;
  final String? color;

  GradePercentageSchema({
    required this.name,
    required this.minPercentage,
    required this.maxPercentage,
    this.color,
  });

  factory GradePercentageSchema.fromJson(Map<String, dynamic> json) {
    return GradePercentageSchema(
      name: json['name']?.toString() ?? '',
      minPercentage: (json['min_percentage'] as num?)?.toDouble() ?? 0.0,
      maxPercentage: (json['max_percentage'] as num?)?.toDouble() ?? 100.0,
      color: json['color']?.toString(),
    );
  }
}

class QuizStatsSchema {
  final double averageScore;
  final double maxScore;
  final double minScore;
  final int submissionCount;

  QuizStatsSchema({
    required this.averageScore,
    required this.maxScore,
    required this.minScore,
    required this.submissionCount,
  });

  factory QuizStatsSchema.fromJson(Map<String, dynamic> json) {
    return QuizStatsSchema(
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      minScore: (json['min_score'] as num?)?.toDouble() ?? 0.0,
      submissionCount: json['submission_count'] as int? ?? 0,
    );
  }
}

class MemberOutSchema {
  final int userId;
  final String username;
  final String? pfpUrl;
  final String rank;
  final DateTime? dateJoined;

  /// Returns the actual image URL by resolving avatar IDs (e.g., avatar_1) to PNG links.
  String? get effectivePfpUrl => AvatarManager.getAvatarUrl(pfpUrl);

  MemberOutSchema({
    required this.userId,
    required this.username,
    this.pfpUrl,
    required this.rank,
    this.dateJoined,
  });

  factory MemberOutSchema.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return MemberOutSchema(
      userId: user?['id'] as int? ?? 0,
      username:
          user?['username']?.toString() ??
          (json['username']?.toString() ?? 'Ismeretlen'),
      pfpUrl: user?['pfp_url']?.toString(),
      rank: json['rank']?.toString() ?? 'MEMBER',
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(json['date_joined'])
          : null,
    );
  }
}

class GroupWithRankOutSchema {
  final int id;
  final String name;
  final String? color;
  final String inviteCode;
  final String rank;

  GroupWithRankOutSchema({
    required this.id,
    required this.name,
    this.color,
    required this.inviteCode,
    required this.rank,
  });

  factory GroupWithRankOutSchema.fromJson(Map<String, dynamic> json) {
    return GroupWithRankOutSchema(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Névtelen csoport',
      color: json['color']?.toString(),
      inviteCode: json['invite_code']?.toString() ?? '',
      rank: json['rank']?.toString() ?? 'MEMBER',
    );
  }
}

class SubmissionOutSchema {
  final int id;
  final int? quizId;
  final String quizTitle;
  final double percentage;
  final String? gradeValue;
  final DateTime? submittedAt;

  SubmissionOutSchema({
    required this.id,
    this.quizId,
    required this.quizTitle,
    required this.percentage,
    this.gradeValue,
    this.submittedAt,
  });

  factory SubmissionOutSchema.fromJson(Map<String, dynamic> json) {
    return SubmissionOutSchema(
      id: json['id'] as int? ?? 0,
      quizId: json['quiz_id'] as int?, // Might be null in some endpoints
      quizTitle:
          json['quiz_project']?.toString() ??
          (json['quiz_title']?.toString() ??
              (json['title']?.toString() ?? 'Kvíz')),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      gradeValue:
          json['grade_value']?.toString() ?? json['grade_label']?.toString(),
      submittedAt: json['date_submitted'] != null
          ? DateTime.tryParse(json['date_submitted'])
          : (json['submitted_at'] != null
                ? DateTime.tryParse(json['submitted_at'])
                : null),
    );
  }
}
