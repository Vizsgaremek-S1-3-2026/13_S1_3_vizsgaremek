// lib/home_page.dart

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onLogout;

  const HomePage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Főoldal'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: onLogout, // A kijelentkezés funkciót hívjuk.
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: const Text(
              'Kijelentkezés',
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Text(
          'Sikeresen bejelentkeztél!',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}