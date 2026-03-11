/*
 * Mit tesztel: Újrahasználható UI komponensek (gombok, kártyák) vizuális megjelenését.
 * Előfeltétel: nincs előfeltétel
 * Várt eredmény: A komponensek pixelpontosan megegyeznek a dizájnnal.
 * Eredmény: Sikeres.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cquizy/home_page.dart'; // Ensure this matches actual path for SideNavItem

void main() {
  testWidgets('SideNavItem Golden Test', (WidgetTester tester) async {
    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Unselected Item
                SideNavItem(
                  label: 'Unselected Item',
                  icon: Icons.home,
                  isSelected: false,
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                // 2. Selected Item
                SideNavItem(
                  label: 'Selected Item',
                  icon: Icons.star,
                  isSelected: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wait for animations to settle (SideNavItem has AnimatedContainer)
    await tester.pumpAndSettle();

    // Verify visual appearance
    // This will generate 'goldens/side_nav_item.png' on first run with --update-goldens
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/side_nav_item.png'),
    );
  });
}
