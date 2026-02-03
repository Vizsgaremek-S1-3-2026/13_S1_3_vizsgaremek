import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Quiz Management Integration Test', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    final randomId = Random().nextInt(10000);
    final projectName = 'Quiz Test Project $randomId';
    final groupName = 'Quiz Test Group $randomId';

    String? token;
    int? projectId;
    int? groupId;
    int? quizId;

    test('1. Setup (Login, Project, Group)', () async {
      token = await apiService.login(testUsername, testPassword);
      expect(token, isNotNull, reason: 'Login failed');

      // Create Project
      final proj = await apiService.createProject(
        token!,
        projectName,
        'For quiz test',
      );
      expect(proj, isNotNull);
      projectId = proj!['id'];

      // Create Group
      final grp = await apiService.createGroup(token!, groupName, '0xFF000000');
      expect(grp, isNotNull);
      groupId = grp!['id'];

      print('Setup complete. Project: $projectId, Group: $groupId');
    });

    test('2. Create Quiz Session', () async {
      expect(token, isNotNull);
      expect(projectId, isNotNull);
      expect(groupId, isNotNull);

      final statTime = DateTime.now();
      final endTime = statTime.add(const Duration(hours: 1));

      print('Creating new quiz session...');
      final quiz = await apiService.createQuiz(
        token!,
        projectId!,
        groupId!,
        statTime,
        endTime,
      );

      expect(quiz, isNotNull, reason: 'Quiz creation failed');
      quizId = quiz!['id'];
      print('Quiz created with ID: $quizId');
    });

    test('3. Verify Quiz in Group List', () async {
      expect(token, isNotNull);
      expect(groupId, isNotNull);
      expect(quizId, isNotNull);

      print('Checking group quizzes...');
      final quizzes = await apiService.getGroupQuizzes(token!, groupId!);

      final foundQuiz = quizzes.firstWhere(
        (q) => q['id'] == quizId,
        orElse: () => {},
      );

      expect(foundQuiz, isNotEmpty, reason: 'Quiz not found in group list');
      expect(foundQuiz['project_name'], projectName);
    });

    test('4. Update Quiz Time', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      final newStart = DateTime.now().add(const Duration(days: 1));
      final newEnd = newStart.add(const Duration(hours: 2));

      print('Updating quiz time...');
      final updated = await apiService.updateQuiz(
        token!,
        quizId!,
        newStart,
        newEnd,
      );

      expect(updated, isNotNull);
      // Verify date strings (simple check)
      expect(updated!['date_start'], contains(newStart.year.toString()));
    });

    test('5. Cleanup (Delete Quiz, Group, Project)', () async {
      expect(token, isNotNull);

      if (quizId != null) {
        print('Deleting quiz $quizId...');
        await apiService.deleteQuiz(token!, quizId!);
      }

      if (groupId != null) {
        print('Deleting group $groupId...');
        await apiService.deleteGroup(token!, groupId!, testPassword);
      }

      if (projectId != null) {
        print('Deleting project $projectId...');
        await apiService.deleteProject(token!, projectId!);
      }
    });
  });
}
