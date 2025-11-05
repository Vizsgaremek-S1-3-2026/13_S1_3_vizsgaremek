// lib/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Az API alap URL-je. Győződj meg róla, hogy a szerver ezen a címen fut.
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

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
        debugPrint('Bejelentkezési hiba: ${response.statusCode} - ${response.body}');
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
      'last_name': userData['lastName'],   // Kulcs átnevezése
      'email': userData['email'],
      'password': userData['password'],
      'pfp_url': userData['avatar_id'],    // 'avatar_id'-t 'pfp_url'-ként küldjük
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(apiData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) { // Sikeres regisztráció (általában 201 Created)
        debugPrint('Sikeres regisztráció: ${response.body}');
        return true;
      } else {
        debugPrint('Regisztrációs hiba: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Hálózati hiba a regisztráció során: $e');
      return false;
    }
  }
}