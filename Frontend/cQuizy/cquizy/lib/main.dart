// lib/main.dart

import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';

import 'theme.dart';

import 'package:provider/provider.dart';
import 'providers/user_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: const MainApp(),
    ),
  );
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
  @override
  void initState() {
    super.initState();
    // Try auto-login when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().tryAutoLogin();
    });
  }

  // Ezt a metódust hívjuk meg, amikor a bejelentkezés sikeres.
  void _handleLogin(String token) {
    context.read<UserProvider>().setToken(token);
  }

  // Ezt a metódust hívjuk meg, amikor a felhasználó kijelentkezik.
  void _handleLogout() {
    context.read<UserProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final theme = Theme.of(context);

    // Show loading indicator while checking for stored token
    if (userProvider.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 24),
              Text(
                'Bejelentkezés...',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userProvider.isLoggedIn) {
      return HomePage(onLogout: _handleLogout);
    } else {
      return LoginPage(onLoginSuccess: _handleLogin);
    }
  }
}
