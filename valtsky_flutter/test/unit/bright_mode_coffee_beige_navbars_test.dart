import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/util/theme.dart';
import 'package:valtsky_flutter/ui/home_page.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_navigation_dock.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('Bright Mode Coffee Beige Palette Tokens', () {
    test('theme tokens match coffee beige design specification', () {
      expect(ValtSkyTheme.coffeeBeige, const Color(0xFFE8DFD5));
      expect(ValtSkyTheme.coffeeBeigeBorder, const Color(0xFFD6CBC0));
      expect(ValtSkyTheme.coffeeBeigeTextPrimary, const Color(0xFF261F1A));
      expect(ValtSkyTheme.coffeeBeigeTextSecondary, const Color(0xFF6A6054));

      // Light Cap Slab (Top Navbar)
      expect(ValtSkyTheme.lightCapSlab, ValtSkyTheme.coffeeBeige);
      expect(ValtSkyTheme.lightCapSlabText, ValtSkyTheme.coffeeBeigeTextPrimary);
      expect(ValtSkyTheme.capSlab(false), ValtSkyTheme.coffeeBeige);
      expect(ValtSkyTheme.capSlabText(false), ValtSkyTheme.coffeeBeigeTextPrimary);

      // Dark Mode remains unaffected
      expect(ValtSkyTheme.capSlab(true), ValtSkyTheme.darkCapSlab);
      expect(ValtSkyTheme.capSlabText(true), ValtSkyTheme.darkCapSlabText);
    });

    test('nav dock contextual accessors return coffee beige in bright mode', () {
      expect(ValtSkyTheme.navDockBackground(false), ValtSkyTheme.coffeeBeige);
      expect(ValtSkyTheme.navDockBorder(false), ValtSkyTheme.coffeeBeigeBorder);
      expect(ValtSkyTheme.navDockActiveIndicator(false), Colors.white);
      expect(ValtSkyTheme.navDockActiveIcon(false), ValtSkyTheme.coffeeBeigeTextPrimary);
      expect(ValtSkyTheme.navDockInactiveIcon(false), ValtSkyTheme.coffeeBeigeTextSecondary);
      expect(ValtSkyTheme.navDockActiveText(false), ValtSkyTheme.coffeeBeigeTextPrimary);
      expect(ValtSkyTheme.navDockInactiveText(false), ValtSkyTheme.coffeeBeigeTextSecondary);

      // Dark mode remains dark ink
      expect(ValtSkyTheme.navDockBackground(true), ValtSkyTheme.darkSurface2);
      expect(ValtSkyTheme.navDockBorder(true), ValtSkyTheme.darkHairline);
      expect(ValtSkyTheme.navDockActiveIndicator(true), ValtSkyTheme.paper);
      expect(ValtSkyTheme.navDockActiveIcon(true), ValtSkyTheme.ink);
    });
  });

  group('ValtSkyNavigationDock Bright Mode Rendering', () {
    testWidgets('renders coffee beige dock with white active indicator in bright mode', (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            bottomNavigationBar: ValtSkyNavigationDock(
              selectedIndex: selected,
              onDestinationSelected: (idx) => selected = idx,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the dock Container
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == ValtSkyTheme.coffeeBeige;
        }
        return false;
      });
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, ValtSkyTheme.coffeeBeige);
      final border = decoration.border as Border;
      expect(border.top.color, ValtSkyTheme.coffeeBeigeBorder);

      // Find active indicator with white background
      final activeIndicatorFinder = find.byWidgetPredicate((widget) {
        if (widget is AnimatedContainer && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == Colors.white && box.shape == BoxShape.circle;
        }
        return false;
      });
      expect(activeIndicatorFinder, findsOneWidget);

      // Verify active label is coffeeBeigeTextPrimary
      final activeTextFinder = find.text('Dashboard');
      expect(activeTextFinder, findsOneWidget);
      final activeText = tester.widget<Text>(activeTextFinder);
      expect(activeText.style?.color, ValtSkyTheme.coffeeBeigeTextPrimary);

      // Verify inactive label is coffeeBeigeTextSecondary
      final inactiveTextFinder = find.text('Settings');
      expect(inactiveTextFinder, findsOneWidget);
      final inactiveText = tester.widget<Text>(inactiveTextFinder);
      expect(inactiveText.style?.color, ValtSkyTheme.coffeeBeigeTextSecondary);
    });

    testWidgets('renders dark ink dock in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            bottomNavigationBar: ValtSkyNavigationDock(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == ValtSkyTheme.darkSurface2;
        }
        return false;
      });
      expect(darkContainerFinder, findsOneWidget);
    });
  });

  group('HomePage Navigation & AppBar Theme Integration', () {
    testWidgets('renders coffee beige AppBar in bright mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          darkTheme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.light,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify top app bar has coffee beige background
      final appBarContainerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.color == ValtSkyTheme.coffeeBeige;
        }
        return false;
      });
      // There are two coffee beige containers in light mode: top AppBar and bottom NavDock
      expect(appBarContainerFinder, findsNWidgets(2));

      // Verify ValtSky title has coffeeBeigeTextPrimary color
      final titleFinder = find.text('ValtSky');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.color, ValtSkyTheme.coffeeBeigeTextPrimary);
    });

    testWidgets('desktop NavigationRail uses paper selected label in dark mode and coffee beige in bright mode', (tester) async {
      // Test desktop width > 1024
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;

      // 1. Dark Mode check
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          darkTheme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      final darkRailFinder = find.byType(NavigationRail);
      expect(darkRailFinder, findsOneWidget);
      final darkRail = tester.widget<NavigationRail>(darkRailFinder);
      expect(darkRail.backgroundColor, ValtSkyTheme.surface(true));
      expect(darkRail.selectedLabelTextStyle?.color, ValtSkyTheme.paper);

      // 2. Light Mode check
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          darkTheme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.light,
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      final lightRailFinder = find.byType(NavigationRail);
      expect(lightRailFinder, findsOneWidget);
      final lightRail = tester.widget<NavigationRail>(lightRailFinder);
      expect(lightRail.backgroundColor, ValtSkyTheme.coffeeBeige);
      expect(lightRail.selectedLabelTextStyle?.color, ValtSkyTheme.coffeeBeigeTextPrimary);
      expect(lightRail.unselectedLabelTextStyle?.color, ValtSkyTheme.coffeeBeigeTextSecondary);
    });
  });
}
