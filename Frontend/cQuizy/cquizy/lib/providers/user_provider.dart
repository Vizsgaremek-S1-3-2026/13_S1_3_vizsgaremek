import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  static const String _tokenKey = 'auth_token';

  User? get user => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  /// Try to auto-login using stored token
  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_tokenKey);

      if (storedToken != null) {
        // Verify token is still valid by fetching user profile
        final user = await _apiService.getUserProfile(storedToken);
        if (user != null) {
          _token = storedToken;
          _user = user;
        } else {
          // Token is invalid, clear it
          await prefs.remove(_tokenKey);
          _token = null;
          _user = null;
        }
      }
    } catch (e) {
      debugPrint('Error during auto-login: $e');
      // On any error, clear the token and show login page
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
      } catch (_) {}
      _token = null;
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set token and save to local storage
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();

    if (token != null) {
      await prefs.setString(_tokenKey, token);
      fetchUser();
    } else {
      await prefs.remove(_tokenKey);
      _user = null;
    }
    notifyListeners();
  }

  /// Logout - clear token from memory and storage
  Future<void> logout() async {
    await setToken(null);
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

  Future<bool> deleteAccount(String password) async {
    if (_token == null) return false;
    try {
      final success = await _apiService.deleteAccount(_token!, password);
      if (success) {
        await logout(); // Logout user and clear stored token
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
    }
    return false;
  }
}
