// lib/main.dart

import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';

import 'theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ThemeInherited(
      themeProvider: _themeProvider,
      child: ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, child) {
          return MaterialApp(
            title: 'cQuizy',
            themeMode: _themeProvider.themeMode,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            debugShowCheckedModeBanner: false,
            home: const AuthGate(),
          );
        },
      ),
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
  bool _isLoggedIn = true; // Kezdet

  // Ezt a metódust hívjuk meg, amikor a bejelentkezés sikeres.
  void _handleLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  // Ezt a metódust hívjuk meg, amikor a felhasználó kijelentkezik.
  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ha a felhasználó be van jelentkezve, a HomePage-t mutatjuk.
    // Ha nincs, akkor a LoginPage-t.
    if (_isLoggedIn) {
      return HomePage(onLogout: _handleLogout);
    } else {
      return LoginPage(onLoginSuccess: _handleLogin);
    }
  }
}
