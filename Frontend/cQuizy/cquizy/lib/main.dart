// lib/main.dart

import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cQuizy',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // Az alkalmazás az AuthGate-tel indul
    );
  }
}

// Ez a widget kezeli, hogy a felhasználó be van-e jelentkezve.
// Állapottól függően a LoginPage-t vagy a HomePage-t jeleníti meg.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = true;

  // Ezt a metódust hívjuk meg, amikor a bejelentkezés sikeres.
  void _handleLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  // Ezt a metódust hívjuk meg, amikor a felhasználó kijelentkezik.
 

  @override
  Widget build(BuildContext context) {
    // Ha a felhasználó be van jelentkezve, a HomePage-t mutatjuk.
    // Ha nincs, akkor a LoginPage-t.
    if (_isLoggedIn) {
      return HomePage();
    } else {
      return LoginPage(onLoginSuccess: _handleLogin);
    }
  }
}