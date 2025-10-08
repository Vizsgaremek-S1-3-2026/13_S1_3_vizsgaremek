// lib/login_page.dart

import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // A bejelentkezési állapotot itt, a saját State osztályán belül tárolja.
  bool isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Letisztultabb kinézet
        elevation: 0,
        actions: [
          // --- VÁLTOZTATÁS KEZDETE ---
          // Az AnimatedSize widget figyeli a gyermekének méretváltozását,
          // és animálja az átmenetet, így a gomb nem "ugrik", hanem
          // finoman változtatja a szélességét.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                // Finom áttűnéses animáció
                return FadeTransition(opacity: animation, child: child);
              },
              child: TextButton(
                // A Key kulcsfontosságú! Az AnimatedSwitcher ez alapján tudja,
                // hogy a widget megváltozott, és le kell futtatni az animációt.
                key: ValueKey<bool>(isLoggedIn),
                onPressed: () {
                  // A setState frissíti a UI-t, amikor az állapot változik.
                  setState(() {
                    isLoggedIn = !isLoggedIn;
                  });
                },
                style: TextButton.styleFrom(
                  // A gomb szövegének színe a témától függően megfelelő lesz
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  backgroundColor: const Color(0xFFED2F5B),
                ),
                child: Text(
                  isLoggedIn ? 'Bejelentkezés' : 'Regisztráció',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          // --- VÁLTOZTATÁS VÉGE ---
          const SizedBox(width: 12), // Egy kis tér a képernyő szélétől
        ],
      ),
      body: Center(
        // Ezt a részt is animáljuk az AnimatedSwitcher segítségével.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          // Ez egy kicsit látványosabb animáció: áttűnés közben kicsit csúszik is.
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2), // Lentről jön be
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            // A kulcs itt is elengedhetetlen az animáció működéséhez.
            key: ValueKey<bool>(isLoggedIn),
            isLoggedIn ? 'Üdvözöllek!' : 'Kérlek, regisztrálj!',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}