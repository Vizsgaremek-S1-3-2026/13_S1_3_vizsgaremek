import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Group Management Integration Test', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    final randomId = Random().nextInt(10000);
    final groupName = 'Integration Test Group $randomId';
    final groupColor = '0xFF42A5F5'; // Blue color hex

    String? token;
    int? groupId;

    test('1. Login', () async {
      token = await apiService.login(testUsername, testPassword);
      expect(token, isNotNull, reason: 'Login failed');
    });

    test('2. Create Group', () async {
      expect(token, isNotNull);
      print('Creating group: $groupName...');

      final result = await apiService.createGroup(
        token!,
        groupName,
        groupColor,
      );

      expect(result, isNotNull, reason: 'Group creation failed');
      expect(result!['name'], groupName);
      expect(result['color'], groupColor);

      groupId = result['id'];
      print('Group created with ID: $groupId');
    });

    test('3. Verify Group List (Read)', () async {
      expect(token, isNotNull);
      expect(groupId, isNotNull);

      print('Fetching user groups...');
      final groups = await apiService.getUserGroups(token!);

      final createdGroup = groups.firstWhere(
        (g) => g['id'] == groupId,
        orElse: () => {},
      );

      expect(
        createdGroup,
        isNotEmpty,
        reason: 'Created group not found in list',
      );
      expect(createdGroup['name'], groupName);
    });

    test('4. Update Group Details', () async {
      expect(token, isNotNull);
      expect(groupId, isNotNull);

      final newName = '$groupName (Renamed)';
      print('Renaming group to: $newName');

      final success = await apiService.updateGroup(
        token!,
        groupId!,
        name: newName,
      );

      expect(success, isTrue, reason: 'Group update failed');

      // Verify
      final groups = await apiService.getUserGroups(token!);
      final updatedGroup = groups.firstWhere((g) => g['id'] == groupId);
      expect(updatedGroup['name'], newName);
    });

    test('5. Delete Group', () async {
      expect(token, isNotNull);
      expect(groupId, isNotNull);

      print('Deleting group $groupId...');
      // Note: deleteGroup requires password for confirmation in ApiService
      final success = await apiService.deleteGroup(
        token!,
        groupId!,
        testPassword,
      );

      expect(success, isTrue, reason: 'Group deletion failed');

      // Verify it's gone (soft delete might still show it but maybe not in active list?
      // api_service.dart line 288 calls /groups/, usually returns active groups)
      final groups = await apiService.getUserGroups(token!);
      final deletedGroup = groups.firstWhere(
        (g) => g['id'] == groupId,
        orElse: () => {},
      );

      expect(
        deletedGroup,
        isEmpty,
        reason: 'Group should not be in the list after deletion',
      );
    });
  });
}
