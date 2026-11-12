import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/ui/views/settings_view.dart';
import 'package:valtsky_flutter/ui/widgets/telegram_profile_card.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_components.dart';
import 'package:valtsky_flutter/util/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
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

      const brainDir = '/home/aditya/.gemini/antigravity/brain/73632573-4b9f-45d4-8925-a60ce53f0d53/screenshots';
      if (Directory(brainDir).existsSync()) {
        File('$brainDir/$filename').writeAsBytesSync(bytes);
      }
    });
  }

  testWidgets('Generate Settings Redesign, Profile, Edit Vault, and 999+ screenshots', (WidgetTester tester) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    // Set configured session
    Prefs.authMethod = 'phone';
    Prefs.userPhoneNumber = '+91 98765 43210';
    Prefs.telegramUserId = '77192834';
    Prefs.telegramUserName = 'Aditya';
    Prefs.telegramUserHandle = 'adityaofficial';
    Prefs.telegramIsPremium = true;
    Prefs.channelId = '-1002938475612';
    Prefs.channelName = 'VaultSky Vault (Aditya)';

    final now = DateTime.now().millisecondsSinceEpoch;
    // Insert 1250 items to showcase 999+ counter
    for (int i = 0; i < 20; i++) {
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/storage/DCIM/IMG_$i.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - i * 1000,
        fileSize: 4 * 1024 * 1024,
        status: MediaItem.statusDone,
        updatedAt: now,
      ));
    }

    // 1. Settings View with Profile Card & Minimized Engine - Dark Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.darkCanvas,
            body: SettingsView(onDataChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'settings_profile_dark_390x844.png',
      );
    }

    // 2. Settings View with Profile Card & Minimized Engine - Light Mode (Coffee Beige)
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.light(),
          themeMode: ThemeMode.light,
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.lightCanvas,
            body: SettingsView(onDataChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'settings_profile_light_390x844.png',
      );
    }

    // 3. Telegram Profile Card in Edit Mode - Dark Mode
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.darkCanvas,
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: TelegramProfileCard(
                  isDark: true,
                  onDisconnect: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'settings_edit_vault_dark_390x844.png',
      );
    }

    // 4. Dashboard View showing 999+ formatting in StatTiles
    {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ValtSkyTheme.dark(),
          themeMode: ThemeMode.dark,
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            backgroundColor: ValtSkyTheme.darkCanvas,
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'TOTAL MEDIA',
                          value: 1420,
                          icon: Icons.photo_library_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: 'SYNCED',
                          value: 1200,
                          icon: Icons.cloud_done_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'IN QUEUE',
                          value: 185,
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: 'FAILED',
                          value: 35,
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await captureScreen(
        tester: tester,
        boundaryKey: boundaryKey,
        filename: 'dashboard_999_plus_dark_390x844.png',
      );
    }
  });
}
