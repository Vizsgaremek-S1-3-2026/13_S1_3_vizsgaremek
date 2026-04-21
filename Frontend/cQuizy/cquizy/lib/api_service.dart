import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/user.dart';
import 'models/stats_models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class ApiService {
  // Az API alap URL-je. Győződj meg róla, hogy a szerver ezen a címen fut.
  //static const String _baseUrl = 'http://127.0.0.1:8000/api';
  static const String _baseUrl =
      'https://cquizy.corneredkey.com/api';

  // Bejelentkezési funkció
  // Visszatérési érték: A szervertől kapott token, ha sikeres, egyébként null.
  Future<String?> login(String username, String password) async {
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
    int? grade2Limit,
    int? grade3Limit,
    int? grade4Limit,
    int? grade5Limit,
  }) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId');

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (color != null) body['color'] = color;
    if (anticheat != null) body['anticheat'] = anticheat;
    if (kiosk != null) body['kiosk'] = kiosk;
    if (grade2Limit != null) body['grade2_limit'] = grade2Limit;
    if (grade3Limit != null) body['grade3_limit'] = grade3Limit;
    if (grade4Limit != null) body['grade4_limit'] = grade4Limit;
    if (grade5Limit != null) body['grade5_limit'] = grade5Limit;

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

  // Delete a group (soft delete)
  // Requires the user to be an ADMIN of the group
  Future<bool> deleteGroup(String token, int groupId, String password) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        debugPrint(
          'Csoport törlési hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a csoport törlése során: $e');
      return false;
    }
  }

  // Create a new project (blueprint)
  Future<Map<String, dynamic>?> createProject(
    String token,
    String name,
    String description,
  ) async {
    final url = Uri.parse('$_baseUrl/blueprints/');
    try {
      debugPrint(
        'CREATE PROJECT PAYLOAD: ${jsonEncode({'name': name, 'desc': description})}',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name, 'desc': description}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          'Projekt létrehozási hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba projekt létrehozása során: $e');
      return null;
    }
  }

  // Create a new Quiz session
  Future<Map<String, dynamic>?> createQuiz(
    String token,
    int projectId,
    int groupId,
    DateTime start,
    DateTime end,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'project_id': projectId,
          'group_id': groupId,
          'date_start': start.toIso8601String(),
          'date_end': end.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          'Teszt létrehozási hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba teszt létrehozása során: $e');
      return null;
    }
  }

  // Get live quiz status of students (Teacher)
  Future<Map<String, dynamic>?> getQuizStatus(String token, int quizId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/status');
    try {
      final response = await http.get(
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
          'Kvíz állapot lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba kvíz állapot lekérése során: $e');
      return null;
    }
  }

  // Update an existing Quiz session
  Future<Map<String, dynamic>?> updateQuiz(
    String token,
    int quizId,
    String dateStartIso,
    String dateEndIso,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId');
    final body = jsonEncode({
      'date_start': dateStartIso,
      'date_end': dateEndIso,
    });
    debugPrint('=== UPDATE QUIZ ===');
    debugPrint('URL: $url');
    debugPrint('Body: $body');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          'Teszt frissítési hiba: ${response.statusCode} - ${response.body}',
        );
        // Try to parse JSON error, otherwise use status code
        String errorMsg;
        try {
          final parsed = jsonDecode(response.body);
          errorMsg = parsed['detail'] ?? parsed['error'] ?? parsed.toString();
        } catch (_) {
          errorMsg = 'Szerverhiba';
        }
        return {
          'error': true,
          'status': response.statusCode,
          'message': errorMsg,
        };
      }
    } catch (e) {
      debugPrint('Hálózati hiba teszt frissítése során: $e');
      return {'error': true, 'message': e.toString()};
    }
  }

  // Delete a quiz session
  Future<bool> deleteQuiz(String token, int quizId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Teszt törlési hiba: $e');
      return false;
    }
  }

  // Get quizzes for a group
  Future<List<Map<String, dynamic>>> getGroupQuizzes(
    String token,
    int groupId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/group/$groupId');
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
          'Tesztek lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba tesztek lekérése során: $e');
      return [];
    }
  }

  // Get all projects (blueprints) for the user
  Future<List<Map<String, dynamic>>> getProjects(String token) async {
    final url = Uri.parse('$_baseUrl/blueprints/');
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
          'Projektek lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba projektek lekérése során: $e');
      return [];
    }
  }

  // Get full project details with blocks
  Future<Map<String, dynamic>?> getProjectDetails(
    String token,
    int projectId,
  ) async {
    final url = Uri.parse('$_baseUrl/blueprints/$projectId/');
    try {
      final response = await http.get(
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
          'Projekt részletek hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba projekt részletek lekérése során: $e');
      return null;
    }
  }

  // Update full project with blocks
  Future<Map<String, dynamic>?> updateProject(
    String token,
    int projectId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$_baseUrl/blueprints/$projectId/');
    try {
      debugPrint('UPDATE PROJECT PAYLOAD: ${jsonEncode(data)}');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        final msg =
            'Projekt frissítési hiba: ${response.statusCode} - $errorBody';
        debugPrint(msg);
        throw ApiException(msg, response.statusCode);
      }
    } catch (e) {
      // Re-throw if it's our ApiException
      if (e is ApiException) rethrow;

      debugPrint('Hálózati hiba projekt frissítése során: $e');
      throw ApiException('Hálózati hiba: $e');
    }
  }

  // Delete a project
  Future<bool> deleteProject(String token, int projectId) async {
    final url = Uri.parse('$_baseUrl/blueprints/$projectId/');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Projekt törlési hiba: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba projekt törlése során: $e');
      return false;
    }
  }

  // Search for user blocks (questions)
  Future<List<Map<String, dynamic>>> searchUserBlocks(
    String token,
    String query, {
    String mode = 'both', // 'question', 'answer', 'both'
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/blueprints/my-blocks/',
    ).replace(queryParameters: {'query': query, 'mode': mode});

    try {
      final response = await http.get(
        uri,
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
          'Blokk keresési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba blokk keresése során: $e');
      return [];
    }
  }

  // Report network issue (unstable network) to the teacher
  // This notifies the teacher that a student experienced network instability during a test
  Future<bool> reportNetworkIssue({
    required String token,
    required int quizId,
    required String
    issueType, // 'unstable_network', 'disconnected', 'reconnected'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/quizzes/$quizId/report-issue/'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'issue_type': issueType,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Hálózati probléma jelentése sikeres');
        return true;
      } else {
        debugPrint(
          'Hálózati probléma jelentése sikertelen: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      // Silent fail - we don't want to block the student if this fails
      debugPrint('Hálózati probléma jelentése sikertelen: $e');
      return false;
    }
  }

  // --- Quiz Taking (Student) ---

  // Start a quiz and get questions
  Future<Map<String, dynamic>?> startQuiz(String token, int quizId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/start');
    try {
      final response = await http.get(
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
          'Kvíz indítása hiba: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Hálózati hiba kvíz indítása során: $e');
      return null;
    }
  }

  // Check lock status
  Future<Map<String, dynamic>?> checkLockStatus(
    String token,
    int quizId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/lock-status');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Submit quiz answers
  Future<Map<String, dynamic>?> submitQuiz(
    String token,
    Map<String, dynamic> submissionData,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/submit/');
    try {
      debugPrint('=== SUBMIT QUIZ DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('PAYLOAD: ${jsonEncode(submissionData)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(submissionData),
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint(
          '!!! Kvíz beadása HIBA: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('!!! Hálózati hiba kvíz beadása során: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // --- Monitoring & Events ---

  // Report a quiz event (Start, Finish, Cheat)
  Future<bool> reportEvent(String token, Map<String, dynamic> eventData) async {
    final url = Uri.parse('$_baseUrl/quizzes/events/log');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(eventData),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Esemény jelentése hiba: $e');
      return false;
    }
  }

  // Report event and return the created event ID (for immediate resolve chaining)
  Future<int?> reportEventGetId(String token, Map<String, dynamic> eventData) async {
    final url = Uri.parse('$_baseUrl/quizzes/events/log');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(eventData),
      );

      debugPrint('reportEventGetId → ${response.statusCode}: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['id'] as int?;
      }
      return null;
    } catch (e) {
      debugPrint('reportEventGetId hiba: $e');
      return null;
    }
  }

  // Get all events (Admin)
  Future<List<Map<String, dynamic>>> getAllEvents(String token) async {
    final url = Uri.parse('$_baseUrl/quizzes/events');
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
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get events for a specific quiz (Teacher/Admin)
  Future<List<Map<String, dynamic>>> getQuizEvents(
    String token,
    int quizId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/events/$quizId');
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
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Resolve/Close a student event (Teacher)
  // decision: "CLOSE"
  Future<bool> resolveStudent(
    String token,
    int eventId,
    String decision,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/events/$eventId/resolve');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'decision': decision}),
      );

      debugPrint('resolveStudent [$decision] eventId=$eventId → ${response.statusCode}: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('resolveStudent error: $e');
      return false;
    }
  }

  // Unlock a specific student (Teacher)
  // POST /quizzes/{quiz_id}/unlock/{student_id}
  Future<bool> unlockStudent(String token, int quizId, int studentId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/unlock/$studentId');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('unlockStudent quizId=$quizId studentId=$studentId → ${response.statusCode}: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('unlockStudent error: $e');
      return false;
    }
  }

  // Block a specific student (Teacher)
  // POST /quizzes/{quiz_id}/block/{student_id}
  Future<bool> blockStudent(String token, int quizId, int studentId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/block/$studentId');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('blockStudent quizId=$quizId studentId=$studentId → ${response.statusCode}: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('blockStudent error: $e');
      return false;
    }
  }

  // Close a specific student's test (Teacher)
  // POST /quizzes/{quiz_id}/close/{student_id}
  Future<Map<String, dynamic>> closeStudentDetailed(String token, int quizId, int studentId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/close/$studentId');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('closeStudent quizId=$quizId studentId=$studentId → ${response.statusCode}: ${response.body}');
      return {
        'success': response.statusCode == 200 || response.statusCode == 204,
        'statusCode': response.statusCode,
        'body': response.body,
      };
    } catch (e) {
      debugPrint('closeStudent error: $e');
      return {
        'success': false,
        'statusCode': 0,
        'body': e.toString(),
      };
    }
  }

  // Get active alerts (Teacher)
  Future<List<Map<String, dynamic>>> getActiveAlerts(
    String token,
    int quizId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/events/$quizId/active');
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
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // --- Grading & Submissions (Teacher) ---

  // Get submissions for a quiz
  Future<List<Map<String, dynamic>>> getQuizSubmissions(
    String token,
    int quizId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/submissions');
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
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Get detailed submission views
  Future<Map<String, dynamic>?> getSubmissionDetails(
    String token,
    int submissionId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/submission/$submissionId');
    debugPrint('=== getSubmissionDetails === URL: $url');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('getSubmissionDetails response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('getSubmissionDetails HIBA: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('getSubmissionDetails EXCEPTION: $e');
      return null;
    }
  }

  // Update points manually
  Future<bool> updateSubmissionPoints(
    String token,
    int submissionId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/quizzes/submission/$submissionId/update-points',
    );
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Override grade
  Future<bool> updateSubmissionGrade(
    String token,
    int submissionId,
    int grade,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/quizzes/submission/$submissionId/update-grade',
    );
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'new_grade': grade.toString()}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get quiz statistics
  Future<Map<String, dynamic>?> getQuizStats(String token, int quizId) async {
    final url = Uri.parse('$_baseUrl/quizzes/$quizId/stats');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get user results for a group
  Future<List<Map<String, dynamic>>> getUserResults(
    String token,
    int groupId,
  ) async {
    final url = Uri.parse('$_baseUrl/quizzes/group/$groupId/results');
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
          'Eredmények lekérési hiba: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Hálózati hiba eredmények lekérése során: $e');
      return [];
    }
  }
  // --- Statistics & Insights (New) ---

  // Get status of user (self)
  Future<Map<String, dynamic>?> getMe(String token) async {
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
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Get groups with rank (re-using existing logic but as a clean helper)
  Future<List<GroupWithRankOutSchema>> getGroupsWithRank(String token) async {
    final data = await getUserGroups(token);
    return data.map((e) => GroupWithRankOutSchema.fromJson(e)).toList();
  }

  // Teacher: Get group overview stats
  Future<AdminGroupOverviewSchema?> getGroupStatsOverview(String token, int groupId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/stats/overview');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return AdminGroupOverviewSchema.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Teacher: Get student leaderboard
  Future<List<AdminStudentStatSchema>> getGroupStudentStats(String token, int groupId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/stats/students');
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
        return data.map((e) => AdminStudentStatSchema.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Teacher: Get quiz difficulty map
  Future<List<AdminQuizStatSchema>> getGroupQuizStats(String token, int groupId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/stats/quizzes');
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
        return data.map((e) => AdminQuizStatSchema.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Get grading scale for a group
  Future<List<GradePercentageSchema>> getGroupGradingScale(String token, int groupId) async {
    final url = Uri.parse('$_baseUrl/groups/$groupId/grading-scale');
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
        return data.map((e) => GradePercentageSchema.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // Student: Get own results for a group
  Future<List<SubmissionOutSchema>> getStudentResults(String token, int groupId) async {
    final data = await getUserResults(token, groupId);
    return data.map((e) => SubmissionOutSchema.fromJson(e)).toList();
  }

  // Common: Get quiz stats (avg/min/max)
  Future<QuizStatsSchema?> getQuizStatsModel(String token, int quizId) async {
    final data = await getQuizStats(token, quizId);
    if (data != null) {
      return QuizStatsSchema.fromJson(data);
    }
    return null;
  }
}
