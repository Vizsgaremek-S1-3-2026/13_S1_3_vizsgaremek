/*
 * Mit tesztel: 
 * Ez a tesztsorozatt egy teljes, valós életbeli folyamatot (Integration Test) hajt végre a szerverrel kommunikálva.
 * 1. Bejelentkezik egy létező felhasználóval a rendszerbe, amivel szerez egy hozzáférési tokent.
 * 2. Létrehoz egy új Projektet az API-n keresztül, és ellenőrzi, hogy sikeres volt-e.
 * 3. Létrehoz egy új Csoportot az API-n keresztül, és validálja annak sikerességét (pl. pontos színkód ellenőrzése).
 * 4. A végén kitakarít maga után: törli a létrehozott Csoportot és Projektet, hogy a tesztadatbázis tiszta maradjon.
 *
 * Előfeltétel: AZ API szerver fut és elérhető a konfigurált címen, illetve létezik egy "test_0" nevű tesztfelhasználó.
 * Várt eredmény: Minden végpont visszajelzése 200-as vagy 201-es HTTP kód (vagy logikai siker), és a létrehozott entitások adatai megegyeznek a beküldöttel.
 * Eredmény: Sikeres.
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/api_service.dart';
import 'dart:math';

void main() {
  group('Project és Csoport Létrehozás Integrációs Teszt', () {
    final apiService = ApiService();
    // Ezzel a felhasználóval lépünk be a teszt futtatásához
    const testUsername = 'test_0';
    const testPassword = 'Wasd1';

    // Generálunk egy véletlen számot, hogy minden futtatáskor egyedi neve legyen a fájloknak
    // Így elkerülhető a névütközés, ha az előző teszt véletlenül nem tudta törölni amit létrehozott.
    final randomId = Random().nextInt(10000);

    // Teszt adatok a projektnek
    final projectName = 'Integrációs Projektünk $randomId';
    final projectDesc =
        'Ezt a projektet az automata integrációs teszt csinálta.';

    // Teszt adatok a csoportnak. Figyelem: A szerver mostanra megköveteli a 6 karakteres HEX színt (pl #FF5500).
    final groupName = 'Integrációs Csoportunk $randomId';
    final groupColor = '#42A5F5';

    String? token;
    int? projectId;
    int? groupId;

    // 1. Lépés: Bejelentkezés. Token nélkül a Create/Update/Delete végpontok nem fogadnak el parancsot.
    test('1. Bejelentkezés a szerverre (test_0 userrel)', () async {
      print('Bejelentkezés folyamatban...');
      token = await apiService.login(testUsername, testPassword);
      // Ha nincs tokenünk, bukik a teszt. Nem érdemes továbbmenni.
      expect(
        token,
        isNotNull,
        reason: 'Sikertelen bejelentkezés, nem kaptunk tokent az API-tól.',
      );
      print('Bejelentkezés sikeres!');
    });

    // 2. Lépés: Projekt létrehozása.
    test('2. Új Projekt létrehozása API-n keresztül', () async {
      expect(token, isNotNull, reason: 'Token hiányzik a bejelentkezésből.');
      print('Projekt létrehozása: $projectName ...');

      final result = await apiService.createProject(
        token!,
        projectName,
        projectDesc,
      );

      // Ha result null, akkor valami hiba történt az ApiService createProject függvényében
      expect(
        result,
        isNotNull,
        reason: 'Nem sikerült létrehozni a projektet (API hiba).',
      );
      // Ellenőrizzük, hogy amit az API visszadott névnek, az megegyezik-e azzal, amit küldtünk
      expect(result!['name'], projectName);

      // Elmentjük a létrehozott projekt ID-ját, hogy később le tudjuk törölni a teszt végén.
      projectId = result['id'];
      print('Projekt sikeresen létrejött. Sorszáma (ID): $projectId');
    });

    // 3. Lépés: Csoport létrehozása.
    test('3. Új Csoport létrehozása API-n keresztül', () async {
      expect(token, isNotNull);
      print('Csoport létrehozása: $groupName ...');

      // Megpróbáljuk létrehozni a csoportot a bejelentkezéskor kapott tokennel
      final result = await apiService.createGroup(
        token!,
        groupName,
        groupColor,
      );

      // Null eredmény esetén HTTP 400, 422 vagy hasonló hálózati hiba történt.
      expect(result, isNotNull, reason: 'Nem sikerült létrehozni a csoportot.');
      expect(result!['name'], groupName);

      // Fontos ellenőrizni, hogy elmentette-e a színt is
      expect(result['color'], groupColor);

      groupId = result['id'];
      print('Csoport sikeresen létrejött. Sorszáma (ID): $groupId');
    });

    // 4. Lépés: Takarítás (Cleanup). Amit a tesztben létrehozunk, azt utána azonnal ki is kell törölni.
    test('4. Takarítás: A létrejött Csoport és Projekt törlése', () async {
      expect(token, isNotNull);

      // Ha a csoport létrejött (tehát nem null az ID), akkor megkíséreljük törölni
      if (groupId != null) {
        print('A(z) $groupId azonosítójú csoport törlése...');
        // A deleteGroup végponthoz jelszó hitelesítés is kell a szerveren biztonsági okokból
        final groupSuccess = await apiService.deleteGroup(
          token!,
          groupId!,
          testPassword,
        );
        expect(
          groupSuccess,
          isTrue,
          reason: 'Nem sikerült a csoport törlése (cleanup fázis).',
        );
      }

      // Ha a projekt létrejött (nem null az ID), szintén töröljük.
      if (projectId != null) {
        print('A(z) $projectId azonosítójú projekt törlése...');
        final projSuccess = await apiService.deleteProject(token!, projectId!);
        expect(
          projSuccess,
          isTrue,
          reason: 'Nem sikerült a projekt törlése (cleanup fázis).',
        );
      }

      print('A takarítás sikeres. A tesztadatbázis tiszta.');
    });
  });
}
