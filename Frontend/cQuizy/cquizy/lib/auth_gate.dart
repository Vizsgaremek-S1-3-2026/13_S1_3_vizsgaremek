import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'providers/user_provider.dart';

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
        body: Column(
          children: [
            const Spacer(flex: 2),
            Center(
              child: LoadingAnimationWidget.newtonCradle(
                color: theme.primaryColor,
                size: 200,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Bejelentkezés...',
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
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
