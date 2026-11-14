import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/main.dart';
import 'package:valtsky_flutter/util/telegram_launcher.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_logo.dart';
import 'package:valtsky_flutter/ui/widgets/app_walkthrough_guide.dart';
import 'package:valtsky_flutter/ui/widgets/interactive_spotlight_tutorial.dart';
import 'package:valtsky_flutter/ui/widgets/dashboard_control_deck.dart';
import 'package:valtsky_flutter/ui/view_models/dashboard_view_model.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/ui/widgets/glass_card.dart';
import 'package:valtsky_flutter/ui/widgets/media_item_card.dart';
import 'package:valtsky_flutter/ui/views/settings_view.dart';

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

  testWidgets('DashboardControlDeck displays Stop Process and Quick Controls', (WidgetTester tester) async {
    bool stopped = false;
    bool paused = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardControlDeck(
            isConfigured: true,
            isPaused: false,
            onTogglePause: () => paused = true,
            onStopProcess: () => stopped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify buttons are rendered
    expect(find.text('QUICK CONTROLS'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop Process'), findsOneWidget);
    expect(find.text('Scan Gallery'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);

    // Tap Stop Process
    await tester.tap(find.text('Stop Process'));
    expect(stopped, isTrue);

    // Tap Pause
    await tester.tap(find.text('Pause'));
    expect(paused, isTrue);
  });

  testWidgets('DashboardControlDeck Pause button is enabled and clickable when isConfigured is true', (WidgetTester tester) async {
    bool paused = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardControlDeck(
            isConfigured: true,
            isPaused: false,
            onTogglePause: () => paused = true,
            onStopProcess: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Pause button is clickable
    await tester.tap(find.text('Pause'));
    expect(paused, isTrue);
  });

  testWidgets('AppWalkthroughGuide displays all 3 tutorial steps correctly', (WidgetTester tester) async {
    bool settingsNavigated = false;
    bool galleryScanned = false;
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppWalkthroughGuide(
            isConfigured: false,
            totalCount: 0,
            isMonitoring: false,
            onNavigateToSettings: () => settingsNavigated = true,
            onScanGallery: () => galleryScanned = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Tutorial Header
    expect(find.text('QUICK START TUTORIAL'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    // Verify 3 Steps
    expect(find.text('Connect Your Vault'), findsOneWidget);
    expect(find.text('Scan Gallery to Receive Media'), findsOneWidget);
    expect(find.text('Monitor & Manage Sync'), findsOneWidget);

    // Tap Step 1 Action (Open Settings)
    expect(find.text('Open Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    expect(settingsNavigated, isTrue);

    // Tap Step 2 Action (Scan Gallery)
    expect(find.text('Scan Gallery'), findsOneWidget);
    await tester.tap(find.text('Scan Gallery'));
    expect(galleryScanned, isTrue);

    // Tap Dismiss
    await tester.tap(find.text('Dismiss'));
    expect(dismissed, isTrue);
  });

  testWidgets('DashboardViewModel handleStopProcess halts engine and clears state', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  final vm = DashboardViewModel();
                  vm.handleStopProcess(context);
                },
                child: const Text('STOP_TEST'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('STOP_TEST'));
    await tester.pumpAndSettle();

    // Confirm Step 1
    await tester.tap(find.text('Proceed'));
    await tester.pumpAndSettle();

    // Confirm Step 2 (Double Verification)
    await tester.tap(find.text('Confirm: Kill & Drain Tank'));
    await tester.pumpAndSettle();

    // Verify engine status is idle and speed notifier says Stopped
    expect(SyncEngine.uploadSpeedNotifier.value, 'Stopped');
    expect(SyncEngine.engineStatusNotifier.value, SyncEngineStatus.idle);
    expect(SyncEngine.currentItemNotifier.value, '');
  });

  testWidgets('InteractiveSpotlightTutorial renders beacons, advances steps, and triggers callbacks', (WidgetTester tester) async {
    int currentStep = 1;
    bool settingsTapped = false;
    bool scanTapped = false;
    bool monitoringTapped = false;
    bool skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return InteractiveSpotlightTutorial(
                currentStep: currentStep,
                onNext: () {
                  setState(() => currentStep++);
                },
                onSkip: () => skipped = true,
                onGoToSettings: () => settingsTapped = true,
                onTriggerScan: () => scanTapped = true,
                onToggleMonitoring: () => monitoringTapped = true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Step 1: Connect Your Vault
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Connect Your Vault'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);

    // Tap Open Settings
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(settingsTapped, isTrue);

    // Step 2: Scan Gallery
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('Scan Gallery'), findsOneWidget);
    expect(find.text('Scan Gallery Now'), findsOneWidget);

    // Tap Scan Gallery Now
    await tester.tap(find.text('Scan Gallery Now'));
    await tester.pump();
    expect(scanTapped, isTrue);

    // Step 3: Start Monitoring
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.text('Start Monitoring'), findsOneWidget);
    expect(find.text('Start & Finish'), findsOneWidget);

    // Tap Start & Finish
    await tester.tap(find.text('Start & Finish'));
    await tester.pump();
    expect(monitoringTapped, isTrue);
    expect(skipped, isTrue);
  });

  testWidgets('Queue tab shows counts and allows removing pictures from upload queue', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Insert 2 pending items
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261106_TEST1.jpg',
      mimeType: 'image/jpeg',
      dateTaken: DateTime.now().millisecondsSinceEpoch,
      fileSize: 3500000,
      status: MediaItem.statusPending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await DatabaseHelper.instance.insert(MediaItem(
      filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261106_TEST2.jpg',
      mimeType: 'image/jpeg',
      dateTaken: DateTime.now().millisecondsSinceEpoch + 100,
      fileSize: 4200000,
      status: MediaItem.statusPending,
      updatedAt: DateTime.now().millisecondsSinceEpoch + 100,
    ));

    await tester.pumpWidget(const ValtSkyApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Queue & Activity
    await tester.tap(find.text('Queue & Activity'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Tab shows Queued
    expect(find.text('Queued'), findsOneWidget);

    // Tap Queued tab
    await tester.tap(find.text('Queued'));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify count banner shows pending in queue
    expect(find.textContaining('PENDING IN QUEUE'), findsOneWidget);

    // Verify Four Telemetry Blocks display live photo and video counts
    expect(find.text('PHOTOS IN QUEUE'), findsOneWidget);
    expect(find.text('VIDEOS IN QUEUE'), findsOneWidget);
    expect(find.text('PHOTOS SYNCED'), findsOneWidget);
    expect(find.text('VIDEOS SYNCED'), findsOneWidget);

    // Verify count of 2 photos in queue
    expect(find.text('2'), findsWidgets);

    // Verify Clear Queue button exists with trash icon
    final trashIcons = find.byIcon(Icons.delete_outline_rounded);
    expect(trashIcons, findsWidgets);

    // Tap Clear Queue button to open confirmation dialog
    await tester.tap(find.text('Clear Queue'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Clear Upload Queue?'), findsOneWidget);
    await tester.tap(find.text('Clear Queue').last);
    await tester.pumpAndSettle();

    // Verify items were removed from database and queue cleared
    final remaining = await DatabaseHelper.instance.getAllPending();
    expect(remaining.length, 0);
  });

  testWidgets('Ultra-narrow 320px viewport renders MediaItemCard with all action buttons without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final item = MediaItem(
      filePath: '/storage/emulated/0/DCIM/huge_video.mp4',
      mimeType: 'video/mp4',
      dateTaken: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      fileSize: 3000000000, // > 2 GB
      status: MediaItem.statusPending,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MediaItemCard(
              item: item,
              onManualUpload: () {},
              onRemove: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 3 elements render without throwing overflow exceptions
    expect(find.text('> 2 GB'), findsOneWidget);
    expect(find.text('UPLOAD'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);
  });

  testWidgets('GlassCard dynamically bypasses BackdropFilter during active uploads to avoid GPU shader jank', (WidgetTester tester) async {
    SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            child: Text('Performance Card'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);

    SyncEngine.engineStatusNotifier.value = SyncEngineStatus.active;
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);

    SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);

    // Flush any debounce timers from DashboardViewModel listeners
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('SettingsView renders Performance & Battery card and toggles Eco/Smooth Mode', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Prefs.smoothUploadMode = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsView(onDataChanged: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify card header and 120 FPS tag
    expect(find.text('Performance & Battery'), findsOneWidget);
    expect(find.text('Zero-lag upload engine'), findsOneWidget);
    expect(find.text('120 FPS'), findsOneWidget);
    expect(find.text('Eco / Smooth Mode'), findsOneWidget);

    // Toggle off to Turbo Mode
    final switchFinder = find.widgetWithText(SwitchListTile, 'Eco / Smooth Mode');
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(Prefs.smoothUploadMode, isFalse);
    expect(find.text('TURBO'), findsOneWidget);

    // Toggle back to Eco Mode
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(Prefs.smoothUploadMode, isTrue);
    expect(find.text('120 FPS'), findsOneWidget);
  });
}
