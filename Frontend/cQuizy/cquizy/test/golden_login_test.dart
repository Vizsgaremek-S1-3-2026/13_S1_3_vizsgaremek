import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/login_page.dart'; // Ensure correct path
import 'package:cquizy/theme.dart'; // For AppTheme

void main() {
  testWidgets('LoginPage Golden Test - Initial State', (
    WidgetTester tester,
  ) async {
    // Determine screen size for a desktop-like view (as shown in screenshot)
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme, // Use actual app theme
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Screenshot shows dark mode
        home: LoginPage(
          onLoginSuccess: (token) {}, // Dummy callback
        ),
      ),
    );

    // Wait for animations (e.g., WaveWidget, AnimatedSwitcher)
    // WaveWidget has infinite animation, so pumpAndSettle might time out.
    // Instead, pump for a specific duration to let initial animations run.
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify visual appearance
    await expectLater(
      find.byType(LoginPage),
      matchesGoldenFile('goldens/login_page_initial.png'),
    );

    // Reset view size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
