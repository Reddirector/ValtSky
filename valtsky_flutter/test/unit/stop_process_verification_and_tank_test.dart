import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/services/backup_scheduler_service.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/ui/view_models/dashboard_view_model.dart';
import 'package:valtsky_flutter/ui/widgets/scheduled_backup_timer_card.dart';
import 'package:valtsky_flutter/ui/widgets/liquid_bucket_sync_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
    await Prefs.init();
    await BackupSchedulerService.instance.init();
    await BackupSchedulerService.instance.setSchedule(2, 0);
    SyncEngine.resetSession();
  });

  tearDown(() {
    BackupSchedulerService.instance.dispose();
  });

  group('Stop Process Double Verification & Queue/Tank Drain Tests', () {
    testWidgets('handleStopProcess requires 2-step verification before killing process and draining tank', (WidgetTester tester) async {
      final viewModel = DashboardViewModel();

      // Seed 5 pending items in queue
      for (int i = 0; i < 5; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo_$i.jpg',
            mimeType: 'image/jpeg',
            fileSize: 1024,
            dateTaken: 1000,
            status: MediaItem.statusPending,
            updatedAt: 1000,
          ),
        );
      }
      await viewModel.refreshStats();
      expect(viewModel.pendingCount, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => viewModel.handleStopProcess(context),
                child: const Text('Stop Process Btn'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Stop Process
      await tester.tap(find.text('Stop Process Btn'));
      await tester.pumpAndSettle();

      // Step 1: Warning dialog appears
      expect(find.text('Kill Process & Empty Queue?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Proceed'), findsOneWidget);

      // Tap Cancel in Step 1 -> Should not clear queue
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(viewModel.pendingCount, 5);

      // Tap Stop Process again to go through full 2-step confirmation
      await tester.tap(find.text('Stop Process Btn'));
      await tester.pumpAndSettle();

      // Proceed
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      // Step 2: Final confirmation dialog appears
      expect(find.text('Confirm Permanent Stop'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm: Kill & Drain Tank'), findsOneWidget);

      // Confirm step 2
      await tester.tap(find.text('Confirm: Kill & Drain Tank'));
      await tester.pumpAndSettle();

      // Queue should now be completely emptied and tank drained to 0.0
      expect(viewModel.pendingCount, 0);
      expect(viewModel.progress, 0.0);
      expect(SyncEngine.sessionProgress, 0.0);
      expect(SyncEngine.uploadSpeedNotifier.value, 'Stopped');
      expect(Prefs.monitoringEnabled, isFalse);
    });
  });

  group('Session Tank Refill & Auto-Empty on Monitoring Cycle Tests', () {
    test('Session tracks uploaded items and marks session complete at 100%', () async {
      // 1. Start new session
      SyncEngine.startNewSession();
      expect(SyncEngine.sessionProgress, 0.0);
      expect(SyncEngine.isSessionComplete, isFalse);

      // 2. Insert items into database
      for (int i = 0; i < 3; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo_$i.jpg',
            mimeType: 'image/jpeg',
            fileSize: 1024,
            dateTaken: 1000,
            status: MediaItem.statusPending,
            updatedAt: 1000,
          ),
        );
      }

      var stats = await SyncEngine.fetchCurrentStats(forceDb: true);
      expect(stats.sessionTotal, 3);
      expect(stats.sessionSynced, 0);
      expect(stats.progress, 0.0);

      // 3. Mark 3 items as uploaded to simulate completion
      for (int i = 0; i < 3; i++) {
        await DatabaseHelper.instance.update(
          MediaItem(
            filePath: '/test/photo_$i.jpg',
            mimeType: 'image/jpeg',
            fileSize: 1024,
            dateTaken: 1000,
            status: MediaItem.statusDone,
            telegramMessageId: 100 + i,
            updatedAt: 1001,
          ),
        );
      }

      stats = await SyncEngine.fetchCurrentStats(forceDb: true);
      // Since all 3 items finished and active queue is 0, session completes at 100%
      expect(stats.progress, 1.0);
      expect(SyncEngine.isSessionComplete, isTrue);

      // 4. When monitoring starts again or alarm clock backup triggers, tank automatically empties
      SyncEngine.startNewSession();
      expect(SyncEngine.sessionProgress, 0.0);
      expect(SyncEngine.sessionTotal, 0);
      expect(SyncEngine.sessionSynced, 0);
      expect(SyncEngine.isSessionComplete, isFalse);
    });
  });

  group('ScheduledBackupTimerCard Save Button Tests', () {
    testWidgets('Save button persists schedule and closes modal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduledBackupTimerCard(
              isDark: true,
              isModal: true,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save Alarm Schedule'), findsOneWidget);
      await tester.tap(find.text('Save Alarm Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Alarm schedule saved for 02:00 AM'), findsOneWidget);
    });
  });

  group('LiquidBucketSyncView Invariant Display Tests', () {
    testWidgets('Never displays synced greater than total and never shows 100% when incomplete', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidBucketSyncView(
              progress: 0.98,
              totalCount: 799,
              syncedCount: 785,
              sessionTotal: 799,
              sessionSynced: 785,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('785 of 799 synced'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('Safely clamps inverted inputs so synced <= total and never displays 799 of 785', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiquidBucketSyncView(
              progress: 0.95,
              totalCount: 785,
              syncedCount: 799,
              sessionTotal: 785,
              sessionSynced: 799,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should clamp to 785 of 785, never showing 799 of 785
      expect(find.text('799 of 785 synced'), findsNothing);
      expect(find.text('785 of 785 synced'), findsOneWidget);
    });
  });
}
