import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/ui/view_models/dashboard_view_model.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_components.dart';
import 'package:valtsky_flutter/ui/widgets/vault_storage_card.dart';
import 'package:valtsky_flutter/util/media_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  tearDown(() {
    MediaScanner.scanHookForTesting = null;
    SyncEngine.instance.stopSync();
  });

  group('Stop Monitoring Independence & Button UI Tests', () {
    testWidgets('VaultStorageCard uses PillButtonVariant.secondary for STOP MONITORING (no red border)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultStorageCard(
              totalCount: 10,
              uploadedCount: 4,
              pendingCount: 6,
              failedCount: 0,
              progress: 0.4,
              isConfigured: true,
              isMonitoring: true,
              isPaused: false,
              isUploading: true,
              onToggleMonitoring: () {},
              onNavigateToSettings: () {},
            ),
          ),
        ),
      );

      final pillFinder = find.byType(PillButton);
      expect(pillFinder, findsOneWidget);
      final pillWidget = tester.widget<PillButton>(pillFinder);

      expect(pillWidget.label, 'STOP MONITORING');
      expect(pillWidget.variant, PillButtonVariant.secondary);
      expect(pillWidget.icon, Icons.sensors_off_rounded);
    });

    testWidgets('VaultStorageCard uses PillButtonVariant.primary for START MONITORING', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultStorageCard(
              totalCount: 10,
              uploadedCount: 4,
              pendingCount: 6,
              failedCount: 0,
              progress: 0.4,
              isConfigured: true,
              isMonitoring: false,
              isPaused: false,
              isUploading: false,
              onToggleMonitoring: () {},
              onNavigateToSettings: () {},
            ),
          ),
        ),
      );

      final pillFinder = find.byType(PillButton);
      expect(pillFinder, findsOneWidget);
      final pillWidget = tester.widget<PillButton>(pillFinder);

      expect(pillWidget.label, 'START MONITORING');
      expect(pillWidget.variant, PillButtonVariant.primary);
      expect(pillWidget.icon, Icons.sensors_rounded);
      expect(find.text('SYNCING'), findsOneWidget);
    });

    test('Stopping monitoring disables gallery auto-indexing without killing active upload process', () async {
      Prefs.channelId = '-1004457069657';
      Prefs.channelName = 'Test Vault';
      Prefs.botToken = '1234567890:ABC-DEF_TEST_TOKEN';
      Prefs.userPhoneNumber = '+1234567890';
      Prefs.monitoringEnabled = true;
      Prefs.uploadPaused = false;

      // Seed 2 pending items
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/tmp/photo1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 1000,
        fileSize: 1024,
        status: MediaItem.statusPending,
        updatedAt: 1000,
      ));
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/tmp/photo2.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 2000,
        fileSize: 2048,
        status: MediaItem.statusPending,
        updatedAt: 2000,
      ));

      final viewModel = DashboardViewModel();
      await viewModel.refreshStats();

      // Trigger toggleMonitoring to STOP monitoring
      final BuildContext mockContext = _MockBuildContext();
      await viewModel.toggleMonitoring(mockContext, onNavigateToSettings: () {});

      // 1. Gallery monitoring is turned off
      expect(Prefs.monitoringEnabled, isFalse);

      // 2. Uploads are NOT paused
      expect(Prefs.uploadPaused, isFalse);

      // 3. Pending items remain intact and queue is active
      expect(viewModel.pendingCount, 2);
    });

    test('purgeDummyMockItems deletes old dummy paths and leaves real files', () async {
      // Insert dummy Android items
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261025_001.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 1000,
        fileSize: 3420100,
        status: MediaItem.statusDone,
        updatedAt: 1000,
      ));
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_4K60_CINEMATIC.mov',
        mimeType: 'video/quicktime',
        dateTaken: 2000,
        fileSize: 2854300000,
        status: MediaItem.statusPending,
        updatedAt: 2000,
      ));
      // Insert real host laptop item
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/home/aditya/Pictures/Screenshots/Screenshot_20261011_164053.png',
        mimeType: 'image/png',
        dateTaken: 3000,
        fileSize: 512000,
        status: MediaItem.statusPending,
        updatedAt: 3000,
      ));

      expect(await DatabaseHelper.instance.getTotalCount(), 3);

      final purged = await DatabaseHelper.instance.purgeDummyMockItems();
      expect(purged, 2);

      final remaining = await DatabaseHelper.instance.getAllItems();
      expect(remaining.length, 1);
      expect(remaining.first.filePath, '/home/aditya/Pictures/Screenshots/Screenshot_20261011_164053.png');
    });
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
