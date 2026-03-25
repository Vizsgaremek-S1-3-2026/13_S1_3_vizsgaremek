/*
 * Mit tesztel: Autentikációs folyamatot (Regisztráció, Bejelentkezés) az API-n keresztül.
 * Előfeltétel: API szerver fut és elérhető.
 * Várt eredmény: Sikeres bejelentkezés és token lekérése.
 * Eredmény: Sikeres.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';

void main() {
  group('Authentication Flow Integration Test', () {
    final apiService = ApiService();
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    // Note: Integration tests dependent on external API state might be flaky.
    // If 'test_0' already exists, registration will fail (or should return failure).
    // This test assumes a clean state or checks if login works regardless.

    test('Register and Login flow with test_0', () async {
      // 1. Attempt Registration
      final registerData = {
        'username': testUsername,
        'password': testPassword,
        'email': 'test_0@example.com',
        'firstName': 'Test',
        'lastName': 'User',
        'nickname': 'TesterZero',
        'avatar_id': null,
      };

      print('Attempting registration for $testUsername...');
      final registerSuccess = await apiService.register(registerData);

      // We log the result but proceed to login, as the user might exist from previous run
      if (registerSuccess) {
        print('Registration successful.');
      } else {
        print(
          'Registration failed (User might already exist). Proceeding to login check.',
        );
      }

      // 2. Attempt Login
      print('Attempting login for $testUsername...');
      final token = await apiService.login(testUsername, testPassword);

      // Verify we got a token
      expect(token, isNotNull, reason: 'Login failed, token was null');
      expect(token, isNotEmpty, reason: 'Token was empty');

      print('Login successful! Token received: ${token?.substring(0, 10)}...');
    });
  });
}
