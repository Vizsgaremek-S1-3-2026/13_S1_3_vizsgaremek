// lib/main.dart

import 'package:flutter/material.dart';
import 'login_page.dart'; // Beimportáljuk a login oldalt

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cQuizy',
      // Sötét téma beállítása Material 3 stílussal az egész alkalmazásban
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      // Az alkalmazás kezdőképernyője a LoginPage lesz.
      home: const LoginPage(),
    );
  }
}