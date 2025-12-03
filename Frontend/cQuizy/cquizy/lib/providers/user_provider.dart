import 'package:flutter/material.dart';
import '../models/user.dart';
import '../api_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  final ApiService _apiService = ApiService();

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      fetchUser();
    } else {
      _user = null;
    }
    notifyListeners();
  }

  Future<void> fetchUser() async {
    if (_token == null) return;
    try {
      final user = await _apiService.getUserProfile(_token!);
      if (user != null) {
        _user = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<bool> updateUser(Map<String, dynamic> data) async {
    if (_token == null) return false;
    try {
      final success = await _apiService.updateUserProfile(_token!, data);
      if (success) {
        await fetchUser(); // Refresh user data immediately

        // Wait a bit and refresh again to ensure server-side changes are reflected
        Future.delayed(const Duration(seconds: 1), () {
          fetchUser();
        });

        return true;
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
    return false;
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_token == null) return false;
    try {
      return await _apiService.changePassword(
        _token!,
        currentPassword,
        newPassword,
      );
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  Future<bool> changeEmail(String newEmail, String password) async {
    if (_token == null) return false;
    try {
      final success = await _apiService.changeEmail(
        _token!,
        newEmail,
        password,
      );
      if (success) {
        await fetchUser(); // Refresh user data immediately

        // Wait a bit and refresh again to ensure server-side changes are reflected
        Future.delayed(const Duration(seconds: 1), () {
          fetchUser();
        });

        return true;
      }
    } catch (e) {
      debugPrint('Error changing email: $e');
    }
    return false;
  }
}
