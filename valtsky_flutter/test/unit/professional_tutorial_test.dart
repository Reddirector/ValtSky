import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/ui/widgets/app_walkthrough_guide.dart';
import 'package:valtsky_flutter/ui/widgets/interactive_spotlight_tutorial.dart';
import 'package:valtsky_flutter/util/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    Prefs.tutorialDismissed = false;
  });

  group('Professional App Tutorial & Small Checkbox Tests', () {
    testWidgets('AppWalkthroughGuide renders small checkbox and toggles Prefs.tutorialDismissed', (tester) async {
      expect(Prefs.tutorialDismissed, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Scaffold(
            body: AppWalkthroughGuide(
              isConfigured: true,
              totalCount: 42,
              isMonitoring: true,
              onNavigateToSettings: () {},
              onScanGallery: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the small checkbox and text label exist
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);

      final labelFinder = find.text("Don't show this again");
      expect(labelFinder, findsOneWidget);

      final initialCheckbox = tester.widget<Checkbox>(checkboxFinder);
      expect(initialCheckbox.value, isFalse);

      // Tap the checkbox
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(Prefs.tutorialDismissed, isTrue);

      final updatedCheckbox = tester.widget<Checkbox>(checkboxFinder);
      expect(updatedCheckbox.value, isTrue);

      // Tap the text label to toggle it back
      await tester.ensureVisible(labelFinder);
      await tester.tap(labelFinder);
      await tester.pumpAndSettle();

      expect(Prefs.tutorialDismissed, isFalse);
    });

    testWidgets('AppWalkthroughGuide displays modernized flow with status badges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Scaffold(
            body: AppWalkthroughGuide(
              isConfigured: true,
              totalCount: 150,
              isMonitoring: true,
              onNavigateToSettings: () {},
              onScanGallery: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Connected status
      expect(find.text('Connect Your Vault'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);

      // Step 2: Auto-scan status with indexed count
      expect(find.text('Scan Gallery & Dual-Lane Uploads'), findsOneWidget);
      expect(find.text('150 indexed'), findsOneWidget);

      // Step 3: Monitoring Active
      expect(find.text('Monitor & Nightly Alarm Loop'), findsOneWidget);
      expect(find.text('Monitoring Active'), findsOneWidget);

      // Action button: Got It
      expect(find.text('Got It'), findsOneWidget);
    });

    testWidgets('InteractiveSpotlightTutorial renders small checkbox and updates Prefs.tutorialDismissed', (tester) async {
      expect(Prefs.tutorialDismissed, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.dark(),
          home: Scaffold(
            body: InteractiveSpotlightTutorial(
              currentStep: 1,
              onNext: () {},
              onSkip: () {},
              onGoToSettings: () {},
              onTriggerScan: () {},
              onToggleMonitoring: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the small checkbox exists in the spotlight card
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);

      expect(find.text("Don't show this again"), findsOneWidget);

      // Tap the checkbox in the spotlight card
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(Prefs.tutorialDismissed, isTrue);
    });

    testWidgets('AppWalkthroughGuide.showWalkthroughSheet opens modal with clean header and checkbox', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  AppWalkthroughGuide.showWalkthroughSheet(
                    context,
                    isConfigured: false,
                    totalCount: 0,
                    isMonitoring: false,
                    onNavigateToSettings: () {},
                    onScanGallery: () {},
                  );
                },
                child: const Text('OPEN_SHEET'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_SHEET'));
      await tester.pumpAndSettle();

      // Verify sheet header
      expect(find.text('ValtSky Quick Guide'), findsOneWidget);
      expect(find.text('4 simple steps to setup & zero-loss backup'), findsOneWidget);

      // Verify small checkbox in sheet
      expect(find.text("Don't show this again"), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });
}
