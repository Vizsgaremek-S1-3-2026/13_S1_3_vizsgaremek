import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/user.dart';

class ApiService {
  // Az API alap URL-je. Győződj meg róla, hogy a szerver ezen a címen fut.
  static const String _baseUrl = 'https://sr701kx0-8000.euw.devtunnels.ms/api';

  // Bejelentkezési funkció
  // Visszatérési érték: A szervertől kapott token, ha sikeres, egyébként null.
  Future<String?> login(String username, String password) async {
    // --- TESZT MÓD ---
    if (username == 'test' && password == 'test') {
      debugPrint('TESZT MÓD: Sikeres bejelentkezés');
      return 'test_token';
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('Sikeres bejelentkezés: $data');
        return data['token']; // A token kinyerése a válaszból
      } else {
        debugPrint(
          'Bejelentkezési hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a bejelentkezés során: $e');
      return null;
    }
  }

  // Regisztrációs funkció
  // Visszatérési érték: Igaz, ha a regisztráció sikeres volt, egyébként hamis.
  Future<bool> register(Map<String, dynamic> userData) async {
    final url = Uri.parse('$_baseUrl/users/register');

    // Az API által elvárt kulcsoknak megfelelően alakítjuk át a térképet.
    final apiData = {
      'username': userData['username'],
      'nickname': userData['nickname'],
      'first_name': userData['firstName'], // Kulcs átnevezése
      'last_name': userData['lastName'], // Kulcs átnevezése
      'email': userData['email'],
      'password': userData['password'],
      'pfp_url': userData['avatar_id'], // 'avatar_id'-t 'pfp_url'-ként küldjük
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(apiData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Sikeres regisztráció (általában 201 Created)
        debugPrint('Sikeres regisztráció: ${response.body}');
        return true;
      } else {
        debugPrint(
          'Regisztrációs hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a regisztráció során: $e');
      return false;
    }
  }

  // Felhasználói profil lekérése
  Future<User?> getUserProfile(String token) async {
    // --- TESZT MÓD ---
    if (token == 'test_token') {
      debugPrint('TESZT MÓD: Mock profil adatok visszaadása');
      return User(
        isSuperuser: true,
        firstName: 'Teszt',
        lastName: 'Elek',
        email: 'teszt.elek@example.com',
        isStaff: true,
        isActive: true,
        dateJoined: DateTime.now().subtract(const Duration(days: 365)),
        nickname: 'Teszter',
      );
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/me');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        debugPrint(
          'Profil lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a profil lekérése során: $e');
      return null;
    }
  }

  // Felhasználói profil frissítése
  Future<bool> updateUserProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    // --- TESZT MÓD ---
    if (token == 'test_token') {
      debugPrint('TESZT MÓD: Profil frissítés szimulálása');
      return true;
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/me');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Profil frissítési hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a profil frissítése során: $e');
      return false;
    }
  }

  // Jelszó módosítása
  Future<bool> changePassword(
    String token,
    String currentPassword,
    String newPassword,
  ) async {
    // --- TESZT MÓD ---
    if (token == 'test_token') {
      debugPrint('TESZT MÓD: Jelszó módosítás szimulálása');
      return true;
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/me/password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Jelszó módosítési hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a jelszó módosítása során: $e');
      return false;
    }
  }
}
