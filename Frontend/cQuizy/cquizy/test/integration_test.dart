import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Full Application Integration Test (Project Management)', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    // Randomize project name to avoid conflicts if previous tests failed to cleanup
    final randomId = Random().nextInt(10000);
    final projectName = 'Integration Test Project $randomId';
    final projectDesc = 'Created by automated integration test';

    String? token;
    int? projectId;

    test('1. Login with test_0', () async {
      print('Attempting login...');
      token = await apiService.login(testUsername, testPassword);
      expect(token, isNotNull, reason: 'Login failed');
      print('Login successful.');
    });

    test('2. Create a new Project', () async {
      expect(token, isNotNull);
      print('Creating project: $projectName...');

      final result = await apiService.createProject(
        token!,
        projectName,
        projectDesc,
      );

      expect(result, isNotNull, reason: 'Project creation failed');
      expect(result!['name'], projectName);

      projectId = result['id'];
      print('Project created with ID: $projectId');
    });

    test('3. Verify Project Details (Read)', () async {
      expect(token, isNotNull);
      expect(projectId, isNotNull);

      print('Fetching details for project $projectId...');
      final details = await apiService.getProjectDetails(token!, projectId!);

      expect(details, isNotNull);
      expect(details!['name'], projectName);
      expect(details['desc'], projectDesc);
      print('Project details verified.');
    });

    test('4. Cleanup: Delete Project', () async {
      expect(token, isNotNull);
      expect(projectId, isNotNull);

      print('Deleting project $projectId...');
      final success = await apiService.deleteProject(token!, projectId!);

      expect(success, isTrue, reason: 'Project deletion failed');

      // Verify it's gone
      final details = await apiService.getProjectDetails(token!, projectId!);
      // Depending on API, it might return null or throw an error.
      // Based on ApiService implementation in lines 790-798, it returns null on failure (non-200).
      expect(
        details,
        isNull,
        reason: 'Project should not exist after deletion',
      );
      print('Project deleted and cleanup verified.');
    });
  });
}
