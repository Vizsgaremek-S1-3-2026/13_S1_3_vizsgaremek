import 'package:flutter/material.dart';

class AppTheme {
  // --- Light Theme Colors ---
  static const Color _lightPrimary = Color(0xFFED2F5B);
  static const Color _lightBackground = Color(0xFFF4F4F4);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightText = Color(0xFF1A1A1A);
  static const Color _lightSubtext = Color(0xFF666666);
  static const Color _lightDivider = Color(0xFFE0E0E0);

  // --- Dark Theme Colors ---
  static const Color _darkPrimary = Color(0xFFED2F5B);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(
    0xFF1E1E1E,
  ); // Slightly lighter than background
  static const Color _darkText = Color(0xFFF0F0F0);
  static const Color _darkSubtext = Color(0xFF9E9E9E);
  static const Color _darkDivider = Color(0xFF333333);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _lightPrimary,
    scaffoldBackgroundColor: _lightBackground,
    cardColor: _lightSurface,
    dividerColor: _lightDivider,
    colorScheme: const ColorScheme.light(
      primary: _lightPrimary,
      surface: _lightSurface,
      onSurface: _lightText,
      secondary: _lightPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightBackground,
      foregroundColor: _lightText,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _lightText),
      bodyMedium: TextStyle(color: _lightText),
      titleMedium: TextStyle(color: _lightSubtext),
    ),
    iconTheme: const IconThemeData(color: _lightText),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _darkPrimary,
    scaffoldBackgroundColor: _darkBackground,
    cardColor: _darkSurface,
    dividerColor: _darkDivider,
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimary,
      surface: _darkSurface,
      onSurface: _darkText,
      secondary: _darkPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkBackground,
      foregroundColor: _darkText,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _darkText),
      bodyMedium: TextStyle(color: _darkText),
      titleMedium: TextStyle(color: _darkSubtext),
    ),
    iconTheme: const IconThemeData(color: _darkText),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // This is a bit tricky without context, but usually we can default to dark or light
      // For now, let's assume system default.
      // To properly return bool, we might need BuildContext, but for the switch state
      // we can check if it's explicitly dark.
      return _themeMode == ThemeMode.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class ThemeInherited extends InheritedNotifier<ThemeProvider> {
  const ThemeInherited({
    super.key,
    required ThemeProvider themeProvider,
    required super.child,
  }) : super(notifier: themeProvider);

  static ThemeProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ThemeInherited>();
    assert(result != null, 'No ThemeInherited found in context');
    return result!.notifier!;
  }
}
