import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/main.dart';
import 'package:valtsky_flutter/util/telegram_launcher.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_logo.dart';

void main() {
  setUp(() async {
    // Initialize mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
  });

  testWidgets('ValtSky UI Navigation & Core Views Smoke Test', (WidgetTester tester) async {
    // Build ValtSky and trigger frame rendering
    await tester.pumpWidget(const ValtSkyApp());
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify app title in AppBar
    expect(find.text('ValtSky'), findsOneWidget);

    // 2. Verify Bottom Navigation Tabs
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Queue & Activity'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // 3. Verify Dashboard components (Clean Metrics & Configure Backup CTA)
    expect(find.text('TOTAL MEDIA'), findsOneWidget);
    expect(find.text('CONFIGURE TELEGRAM BACKUP'), findsOneWidget);

    // 4. Switch to Activity Tab
    await tester.tap(find.text('Queue & Activity'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Activity view filter chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);

    // 5. Switch to Settings Tab
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Settings view shows Direct Telegram Login and Any-Size Lossless Engine
    expect(find.text('Direct Telegram Login'), findsOneWidget);
    expect(find.text('Any-Size Lossless Engine'), findsOneWidget);

    // Test switching to Advanced Custom Bot Token & Channel ID mode
    await tester.tap(find.text('Advanced: Use Custom Bot Token & Channel ID'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Telegram Bot API'), findsOneWidget);
    expect(find.text('BOT TOKEN'), findsOneWidget);
    expect(find.text('CHANNEL ID'), findsOneWidget);

    // 6. Navigate back to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CONFIGURE TELEGRAM BACKUP'), findsOneWidget);
  });

  testWidgets('Oversized > 2GB 4-Click Manual Upload Flow Test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Insert an oversized 2.85 GB media item into the database
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_4K60_CINEMATIC.mov',
      mimeType: 'video/quicktime',
      dateTaken: DateTime.now().millisecondsSinceEpoch,
      fileSize: 2854300000,
      status: MediaItem.statusPending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));

    await tester.pumpWidget(const ValtSkyApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Navigate to Queue & Activity
    await tester.tap(find.text('Queue & Activity'));
    await tester.pump(const Duration(milliseconds: 300));

    // CLICK 1: Tap the '> 2 GB' filter chip
    expect(find.text('> 2 GB'), findsOneWidget);
    await tester.tap(find.text('> 2 GB'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Oversized Vault header, items, and Open Channel action button appear
    expect(find.text('OVERSIZED VAULT (> 2 GB)'), findsOneWidget);
    expect(find.text('VID_20261101_4K60_CINEMATIC.mov'), findsOneWidget);
    expect(find.text('Open Channel'), findsOneWidget);

    // CLICK 2: Tap 'UPLOAD ALL OVERSIZED'
    expect(find.text('UPLOAD ALL OVERSIZED'), findsOneWidget);
    await tester.tap(find.text('UPLOAD ALL OVERSIZED'));
    await tester.pumpAndSettle();

    // Verify Assistant Sheet opens with Target Channel & 4-Click Tracker
    expect(find.text('Manual 2GB+ Lossless Uploader'), findsOneWidget);
    expect(find.text('TARGET TELEGRAM CHANNEL'), findsOneWidget);

    // CLICK 3: Tap 'START 2GB+ LOSSLESS UPLOAD'
    final uploadBtn = find.textContaining('START 2GB+ LOSSLESS UPLOAD');
    expect(uploadBtn, findsOneWidget);
    await tester.scrollUntilVisible(uploadBtn, 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(uploadBtn);

    // Advance test clock for the simulation ticks and db update
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Verify Lossless Backup Confirmed
    expect(find.text('Lossless Backup Confirmed'), findsOneWidget);

    // CLICK 4: Tap 'Open Telegram Channel'
    expect(find.text('Open Telegram Channel'), findsOneWidget);
    await tester.tap(find.text('Open Telegram Channel'));
    await tester.pumpAndSettle();
  });

  test('TelegramLauncher URL Resolution & Fallback Test', () {
    // 1. Public handle with @
    Prefs.channelId = '@valtsky_backup';
    expect(TelegramLauncher.getChannelUrl(), 'https://t.me/valtsky_backup');

    // 2. Public handle without @
    Prefs.channelId = 'my_cloud_vault';
    expect(TelegramLauncher.getChannelUrl(), 'https://t.me/my_cloud_vault');

    // 3. Private supergroup/channel starting with -100
    Prefs.channelId = '-1001928374650';
    expect(TelegramLauncher.getChannelUrl(), 'https://t.me/c/1928374650');

    // 4. Fallback to bot username
    Prefs.channelId = '';
    Prefs.channelName = '';
    Prefs.botName = 'ValtSkyBackupBot';
    expect(TelegramLauncher.getChannelUrl(), 'https://t.me/ValtSkyBackupBot');

    // 5. Default web telegram
    Prefs.botName = '';
    expect(TelegramLauncher.getChannelUrl(), 'https://web.telegram.org');
  });

  testWidgets('ValtSkyLogo Widget renders correctly in color and monochrome modes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ValtSkyLogo(size: 32),
              ValtSkyLogo(size: 48, isMonochrome: true),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ValtSkyLogo), findsNWidgets(2));
  });
}
