import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Monitoring & Cheating Events Integration Test', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    final randomId = Random().nextInt(10000);
    final groupName = 'Monitor Group $randomId';
    final projectName = 'Monitor Project $randomId';

    String? token;
    int? projectId;
    int? groupId;
    int? quizId;

    test('1. Setup', () async {
      token = await apiService.login(testUsername, testPassword);
      expect(token, isNotNull);

      final proj = await apiService.createProject(
        token!,
        projectName,
        'Monitor Test',
      );
      projectId = proj!['id'];

      final grp = await apiService.createGroup(token!, groupName, '0xFF0000FF');
      groupId = grp!['id'];

      final start = DateTime.now();
      final end = start.add(const Duration(hours: 1));
      final quiz = await apiService.createQuiz(
        token!,
        projectId!,
        groupId!,
        start,
        end,
      );
      quizId = quiz!['id'];
    });

    test('2. Report Cheat Event (Student side)', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      print('Reporting "tab_switch" event...');
      final eventData = {
        'quiz_id': quizId,
        'event_type': 'tab_switch',
        'description': 'Student switched tabs at ${DateTime.now()}',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final success = await apiService.reportEvent(token!, eventData);
      expect(success, isTrue, reason: 'Event reporting failed');
    });

    test('3. Retrieve Events (Teacher side)', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      print('Fetching events for quiz $quizId...');
      final events = await apiService.getQuizEvents(token!, quizId!);

      expect(events, isNotEmpty, reason: 'No events found');

      final recentEvent = events.firstWhere(
        (e) => e['event_type'] == 'tab_switch',
        orElse: () => {},
      );

      expect(recentEvent, isNotEmpty);
      expect(recentEvent['description'], contains('switched tabs'));
      print('Event verified: ${recentEvent['event_type']}');
    });

    test('4. Resolve Event (Unblock/Ack)', () async {
      expect(token, isNotNull);
      expect(quizId, isNotNull);

      final events = await apiService.getQuizEvents(token!, quizId!);
      final eventId = events.first['id'];

      print('Resolving event $eventId...');
      final success = await apiService.resolveEvent(token!, eventId);

      expect(success, isTrue, reason: 'Event resolution failed');

      // Verify is_resolved (if API updates it status)
      final updatedEvents = await apiService.getQuizEvents(token!, quizId!);
      final updatedEvent = updatedEvents.firstWhere((e) => e['id'] == eventId);
      // Assuming 'is_resolved' or 'status' field changes.
      // If the API logic deletes it or marks it solved, we verify logic.
      // Based on typical implementaiton:
      expect(updatedEvent['resolved'], isTrue); // or similar key
    });

    test('5. Cleanup', () async {
      if (quizId != null) await apiService.deleteQuiz(token!, quizId!);
      if (groupId != null)
        await apiService.deleteGroup(token!, groupId!, testPassword);
      if (projectId != null) await apiService.deleteProject(token!, projectId!);
    });
  });
}
