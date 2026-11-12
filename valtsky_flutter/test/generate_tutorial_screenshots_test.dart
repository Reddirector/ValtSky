import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  Future<void> captureScreen({
    required WidgetTester tester,
    required GlobalKey boundaryKey,
    required String filename,
  }) async {
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final targetDir = Directory('../docs/redesign').existsSync()
          ? Directory('../docs/redesign')
          : Directory('docs/redesign');
      if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
      final file = File('${targetDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Also copy to brain artifacts screenshots dir if it exists
      const brainDir = '/home/aditya/.gemini/antigravity/brain/73632573-4b9f-45d4-8925-a60ce53f0d53/screenshots';
      if (Directory(brainDir).existsSync()) {
        File('$brainDir/$filename').writeAsBytesSync(bytes);
      }
    });
  }

  testWidgets('Generate professional tutorial modal and spotlight screenshots', (WidgetTester tester) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    // 1. Tutorial Modal Bottom Sheet - Light Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.light(),
          themeMode: ThemeMode.light,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.coffeeBeige,
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const Key('open_sheet_btn'),
                  onPressed: () {
                    AppWalkthroughGuide.showWalkthroughSheet(
                      context,
                      isConfigured: true,
                      totalCount: 42,
                      isMonitoring: true,
                      onNavigateToSettings: () {},
                      onScanGallery: () {},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'tutorial_modal_light_390x844.png',
      );
    }

    // 2. Tutorial Modal Bottom Sheet - Dark Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.ink,
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const Key('open_sheet_btn_dark'),
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
                  child: const Text('Open Dark'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_sheet_btn_dark')));
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'tutorial_modal_dark_390x844.png',
      );
    }

    // 3. Interactive Spotlight Tour - Light Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.light(),
          themeMode: ThemeMode.light,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.coffeeBeige,
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

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'tutorial_spotlight_light_390x844.png',
      );
    }

    // 4. Interactive Spotlight Tour - Dark Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.ink,
            body: InteractiveSpotlightTutorial(
              currentStep: 2,
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

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'tutorial_spotlight_dark_390x844.png',
      );
    }
  });
}
