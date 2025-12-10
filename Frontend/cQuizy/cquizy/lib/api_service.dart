import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/user.dart';

class ApiService {
  // Az API alap URL-je. Győződj meg róla, hogy a szerver ezen a címen fut.
  //static const String _baseUrl = 'http://127.0.0.1:8000/api';
  static const String _baseUrl =
      'https://one3-s1-3-vizsgaremek.onrender.com/api';

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
        id: 1,
        username: 'testuser',
        isSuperuser: true,
        firstName: 'Teszt',
        lastName: 'Elek',
        email: 'teszt.elek@example.com',
        isStaff: true,
        isActive: true,
        dateJoined: DateTime.now().subtract(const Duration(days: 365)),
        nickname: 'Teszter',
        pfpUrl: 'https://via.placeholder.com/150',
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

    final url = Uri.parse('$_baseUrl/users/me/change-password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Jelszó módosítási hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a jelszó módosítása során: $e');
      return false;
    }
  }

  // Fiók törlése
  Future<bool> deleteAccount(String token, String password) async {
    // --- TESZT MÓD ---
    if (token == 'test_token') {
      debugPrint('TESZT MÓD: Fiók törlése szimulálása');
      return true;
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/me');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Fiók törlési hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a fiók törlése során: $e');
      return false;
    }
  }

  // Email cím módosítása
  Future<bool> changeEmail(
    String token,
    String newEmail,
    String password,
  ) async {
    // --- TESZT MÓD ---
    if (token == 'test_token') {
      debugPrint('TESZT MÓD: Email módosítás szimulálása');
      return true;
    }
    // -----------------

    final url = Uri.parse('$_baseUrl/users/me/change-email');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': newEmail, 'password': password}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Email módosítási hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba az email módosítása során: $e');
      return false;
    }
  }

  // Csoportok lekérése
  Future<List<Map<String, dynamic>>> getUserGroups(String token) async {
    final url = Uri.parse('$_baseUrl/groups/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint(
          'Csoportok lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba a csoportok lekérése során: $e');
      return [];
    }
  }

  // Csoport tagjainak lekérése
  Future<List<Map<String, dynamic>>> getGroupMembers(
    String token,
    int groupId,
  ) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/members');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint(
          'Csoport tagok lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba a csoport tagok lekérése során: $e');
      return [];
    }
  }

  // Tag eltávolítása
  Future<bool> removeMember(String token, int groupId, int userId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/members/$userId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint(
          'Tag eltávolítási hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a tag eltávolítása során: $e');
      return false;
    }
  }

  // Admin jog átadása
  Future<bool> transferAdmin(String token, int groupId, int userId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/transfer');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Admin átadási hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba az admin jog átadása során: $e');
      return false;
    }
  }

  // Join a group using invite code
  Future<Map<String, dynamic>?> joinGroup(
    String token,
    String inviteCode,
  ) async {
    final url = Uri.parse('$_baseUrl/groups/join');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'invite_code': inviteCode}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(
          'Csoporthoz csatlakozás hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba csoporthoz csatlakozás során: $e');
      return null;
    }
  }

  // Create a new group
  Future<Map<String, dynamic>?> createGroup(
    String token,
    String name,
    String color,
  ) async {
    final url = Uri.parse('$_baseUrl/groups/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name, 'color': color}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          'Csoport létrehozási hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba csoport létrehozása során: $e');
      return null;
    }
  }

  // Leave a group
  Future<bool> leaveGroup(String token, int groupId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/leave');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint(
          'Csoport elhagyási hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a csoport elhagyása során: $e');
      return false;
    }
  }

  // Update group settings (name, color, anticheat, kiosk)
  Future<bool> updateGroup(
    String token,
    int groupId, {
    String? name,
    String? color,
    bool? anticheat,
    bool? kiosk,
  }) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId');

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (color != null) body['color'] = color;
    if (anticheat != null) body['anticheat'] = anticheat;
    if (kiosk != null) body['kiosk'] = kiosk;

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Csoport frissítés hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba csoport frissítése során: $e');
      return false;
    }
  }

  // Regenerate invite code for a group
  Future<Map<String, dynamic>?> regenerateInviteCode(
    String token,
    int groupId,
  ) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/regenerate-invite');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          'Meghívókód generálás hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba meghívókód generálása során: $e');
      return null;
    }
  }
}
