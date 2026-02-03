import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Student Quiz Flow Integration Test', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    final randomId = Random().nextInt(10000);
    // Unique names verify isolation
    final projectName = 'Student Flow Project $randomId';
    final groupName = 'Student Flow Group $randomId';

    String? token;
    int? projectId;
    int? groupId;
    int? quizId;

    test('1. Setup Environment (Project, Group, Quiz)', () async {
      token = await apiService.login(testUsername, testPassword);
      expect(token, isNotNull, reason: 'Login failed');

      // 1. Create Project with a question block
      // We need at least one block to answer
      // Using 'createProject' first then 'updateProject' with blocks
      final proj = await apiService.createProject(
        token!,
        projectName,
        'Flow Test',
      );
      expect(proj, isNotNull);
      projectId = proj!['id'];

      final updateData = {
        'name': projectName,
        'desc': 'Flow Test',
        'blocks': [
          {
            'type': 'single',
            'question': 'What is 2+2?',
            'timer': 30,
            'answers': [
              {'text': '3', 'is_correct': false},
              {'text': '4', 'is_correct': true},
            ],
          },
        ],
      };
      await apiService.updateProject(token!, projectId!, updateData);

      // 2. Create Group
      final grp = await apiService.createGroup(token!, groupName, '0xFF00FF00');
      expect(grp, isNotNull);
      groupId = grp!['id'];

      // 3. Create active Quiz
      final startTime = DateTime.now().subtract(const Duration(minutes: 5));
      final endTime = DateTime.now().add(const Duration(minutes: 30));
      final quiz = await apiService.createQuiz(
        token!,
        projectId!,
        groupId!,
        startTime,
        endTime,
      );
      expect(quiz, isNotNull);
      quizId = quiz!['id'];

      print('Environment ready. QuizID: $quizId');
    });

    test('2. Start Quiz (Get Questions)', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      print('Student starting quiz...');
      final quizData = await apiService.startQuiz(token!, quizId!);

      expect(quizData, isNotNull, reason: 'Failed to start quiz');

      // Check structure
      expect(quizData!.containsKey('questions'), isTrue);
      // Depending on backend implementation, questions might be under 'questions' or 'blocks'
      // Based on typical structure: {'quiz': {...}, 'questions': [...]}
      // Or just the Quiz object which has 'blocks'?
      // ApiService line 938 casts response to Map.

      final questions = quizData['questions'] as List?;
      expect(questions, isNotEmpty, reason: 'No questions returned');
      expect(questions!.first['question'], 'What is 2+2?');
    });

    test('3. Submit Answers', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      // We need the question ID (block ID) to submit answer
      // Let's re-fetch start to get IDs
      final quizData = await apiService.startQuiz(token!, quizId!);
      final questions = quizData!['questions'] as List;
      final firstQ = questions.first;
      final blockId = firstQ['id'];

      // Find the correct option ID if needed, or just send text depending on type
      // For 'single', we send 'option_id'.
      final answers = firstQ['answers'] as List;
      final correctOption = answers.firstWhere((a) => a['text'] == '4');
      final optionId = correctOption['id'];

      print('Submitting answer for Block $blockId, Option $optionId...');

      final submissionData = {
        'quiz_id': quizId,
        'answers': [
          {'block_id': blockId, 'option_id': optionId, 'answer_text': ''},
        ],
      };

      final result = await apiService.submitQuiz(token!, submissionData);

      expect(result, isNotNull, reason: 'Submission failed');
      // Usually returns a submission object or success message
      print('Submission successful.');
    });

    test('4. Verify Submission (Teacher View)', () async {
      // Check if submission appears in teacher's list
      print('Checking submissions list...');
      final subs = await apiService.getQuizSubmissions(token!, quizId!);

      expect(subs, isNotEmpty);
      final mySub = subs.last; // Assuming logic
      expect(mySub['quiz'], quizId); // or similar reference
      // Might check score if calculated immediately
      // expect(mySub['score'], greaterThan(0));
    });

    test('5. Cleanup', () async {
      if (quizId != null) await apiService.deleteQuiz(token!, quizId!);
      if (groupId != null)
        await apiService.deleteGroup(token!, groupId!, testPassword);
      if (projectId != null) await apiService.deleteProject(token!, projectId!);
    });
  });
}
