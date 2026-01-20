import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- High Contrast Light Theme Colors ---
  static const Color _hcLightPrimary = Color(0xFFD41E47);
  static const Color _hcLightBackground = Color(0xFFFFFFFF);
  static const Color _hcLightSurface = Color(0xFFFFFFFF);
  static const Color _hcLightText = Color(0xFF000000);
  static const Color _hcLightSubtext = Color(0xFF333333);
  static const Color _hcLightDivider = Color(0xFF000000);

  // --- High Contrast Dark Theme Colors ---
  static const Color _hcDarkPrimary = Color(0xFFFF4D73);
  static const Color _hcDarkBackground = Color(0xFF000000);
  static const Color _hcDarkSurface = Color(0xFF0A0A0A);
  static const Color _hcDarkText = Color(0xFFFFFFFF);
  static const Color _hcDarkSubtext = Color(0xFFCCCCCC);
  static const Color _hcDarkDivider = Color(0xFFFFFFFF);

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

  // High Contrast Light Theme
  static final ThemeData highContrastLightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _hcLightPrimary,
    scaffoldBackgroundColor: _hcLightBackground,
    cardColor: _hcLightSurface,
    dividerColor: _hcLightDivider,
    colorScheme: const ColorScheme.light(
      primary: _hcLightPrimary,
      surface: _hcLightSurface,
      onSurface: _hcLightText,
      secondary: _hcLightPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _hcLightBackground,
      foregroundColor: _hcLightText,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _hcLightText, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: _hcLightText, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(
        color: _hcLightSubtext,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconTheme: const IconThemeData(color: _hcLightText),
  );

  // High Contrast Dark Theme
  static final ThemeData highContrastDarkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _hcDarkPrimary,
    scaffoldBackgroundColor: _hcDarkBackground,
    cardColor: _hcDarkSurface,
    dividerColor: _hcDarkDivider,
    colorScheme: const ColorScheme.dark(
      primary: _hcDarkPrimary,
      surface: _hcDarkSurface,
      onSurface: _hcDarkText,
      secondary: _hcDarkPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _hcDarkBackground,
      foregroundColor: _hcDarkText,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: _hcDarkText, fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(color: _hcDarkText, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(
        color: _hcDarkSubtext,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconTheme: const IconThemeData(color: _hcDarkText),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _hapticEnabled = true;

  static const String _themeModeKey = 'theme_mode';
  static const String _fontScaleKey = 'font_scale';
  static const String _highContrastKey = 'high_contrast';
  static const String _hapticEnabledKey = 'haptic_enabled';

  ThemeProvider() {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;
  bool get hapticEnabled => _hapticEnabled;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isLightMode => _themeMode == ThemeMode.light;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIndex = prefs.getInt(_themeModeKey);
      if (modeIndex != null) {
        _themeMode = ThemeMode.values[modeIndex];
      }

      _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
      _highContrast = prefs.getBool(_highContrastKey) ?? false;
      _hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('Error saving theme setting $key: $e');
    }
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveSetting(_themeModeKey, _themeMode.index);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSetting(_themeModeKey, mode.index);
    notifyListeners();
  }

  void setFontScale(double scale) {
    _fontScale = scale.clamp(0.8, 1.5);
    _saveSetting(_fontScaleKey, _fontScale);
    notifyListeners();
  }

  void setHighContrast(bool value) {
    _highContrast = value;
    _saveSetting(_highContrastKey, value);
    notifyListeners();
  }

  void setHapticEnabled(bool value) {
    _hapticEnabled = value;
    _saveSetting(_hapticEnabledKey, value);
    notifyListeners();
  }

  void triggerHaptic() {
    if (!_hapticEnabled) return;
    HapticFeedback.mediumImpact();
  }

  // Get the appropriate theme based on high contrast setting
  ThemeData getLightTheme() {
    return _highContrast
        ? AppTheme.highContrastLightTheme
        : AppTheme.lightTheme;
  }

  ThemeData getDarkTheme() {
    return _highContrast ? AppTheme.highContrastDarkTheme : AppTheme.darkTheme;
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
