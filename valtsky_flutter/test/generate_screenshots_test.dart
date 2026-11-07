import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/ui/home_page.dart';
import 'package:valtsky_flutter/util/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();

    // Populate with representative data: 4 items (1 done, 2 pending, 1 failed)
    final now = DateTime.now().millisecondsSinceEpoch;
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261101_001.jpg',
      mimeType: 'image/jpeg',
      dateTaken: now - 3600000,
      fileSize: 4 * 1024 * 1024,
      status: MediaItem.statusDone,
      updatedAt: now,
    ));
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261101_002.jpg',
      mimeType: 'image/jpeg',
      dateTaken: now - 1800000,
      fileSize: 6 * 1024 * 1024,
      status: MediaItem.statusPending,
      updatedAt: now,
    ));
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_003.mp4',
      mimeType: 'video/mp4',
      dateTaken: now - 900000,
      fileSize: 120 * 1024 * 1024,
      status: MediaItem.statusPending,
      updatedAt: now,
    ));
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_004.mp4',
      mimeType: 'video/mp4',
      dateTaken: now - 300000,
      fileSize: 2200 * 1024 * 1024, // > 2 GB
      status: MediaItem.statusFailed,
      errorReason: 'FLOOD_WAIT_300',
      updatedAt: now,
    ));
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
      final file = File('/home/aditya/Desktop/valtsky/docs/redesign/$filename');
      await file.writeAsBytes(bytes);
    });
  }

  testWidgets('Generate all required redesign screenshots', (WidgetTester tester) async {
    final targets = [
      {'name': 'dashboard_dark_390x844.png', 'tab': 0, 'theme': ThemeMode.dark, 'size': const Size(390, 844)},
      {'name': 'dashboard_light_390x844.png', 'tab': 0, 'theme': ThemeMode.light, 'size': const Size(390, 844)},
      {'name': 'activity_dark_390x844.png', 'tab': 1, 'theme': ThemeMode.dark, 'size': const Size(390, 844)},
      {'name': 'activity_light_390x844.png', 'tab': 1, 'theme': ThemeMode.light, 'size': const Size(390, 844)},
      {'name': 'settings_dark_390x844.png', 'tab': 2, 'theme': ThemeMode.dark, 'size': const Size(390, 844)},
      {'name': 'settings_light_390x844.png', 'tab': 2, 'theme': ThemeMode.light, 'size': const Size(390, 844)},
      {'name': 'dashboard_tablet_800x1280.png', 'tab': 0, 'theme': ThemeMode.dark, 'size': const Size(800, 1280)},
      {'name': 'dashboard_desktop_1440x900.png', 'tab': 0, 'theme': ThemeMode.dark, 'size': const Size(1440, 900)},
    ];

    for (final target in targets) {
      final size = target['size'] as Size;
      final themeMode = target['theme'] as ThemeMode;
      final tabIndex = target['tab'] as int;
      final filename = target['name'] as String;

      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      final GlobalKey boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.light(),
          darkTheme: ValtSkyTheme.dark(),
          themeMode: themeMode,
          home: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const HomePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (tabIndex == 1) {
        await tester.tap(find.text('Queue & Activity'));
        await tester.pumpAndSettle();
      } else if (tabIndex == 2) {
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
      }

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: filename,
      );
    }
  });
}
