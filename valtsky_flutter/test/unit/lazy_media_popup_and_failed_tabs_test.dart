import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/ui/widgets/lazy_media_list_sheet.dart';
import 'package:valtsky_flutter/ui/views/activity_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  tearDown(() {
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('Lazy Loading & Mime Filter Database Tests', () {
    test('getItemCount and getAllItems correctly filter by status and isVideo', () async {
      // 1. Seed items across photos and videos with different statuses
      final now = DateTime.now().millisecondsSinceEpoch;

      // Pending: 3 photos, 2 videos
      for (int i = 0; i < 3; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo_pending_$i.jpg',
            mimeType: 'image/jpeg',
            dateTaken: now,
            fileSize: 1024 * 100,
            status: MediaItem.statusPending,
            updatedAt: now,
          ),
        );
      }
      for (int i = 0; i < 2; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/video_pending_$i.mp4',
            mimeType: 'video/mp4',
            dateTaken: now,
            fileSize: 1024 * 500,
            status: MediaItem.statusPending,
            updatedAt: now,
          ),
        );
      }

      // Done: 4 photos, 1 video
      for (int i = 0; i < 4; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo_done_$i.jpg',
            mimeType: 'image/jpeg',
            dateTaken: now,
            fileSize: 1024 * 100,
            status: MediaItem.statusDone,
            updatedAt: now,
          ),
        );
      }
      await DatabaseHelper.instance.insert(
        MediaItem(
          filePath: '/test/video_done_0.mp4',
          mimeType: 'video/mp4',
          dateTaken: now,
          fileSize: 1024 * 500,
          status: MediaItem.statusDone,
          updatedAt: now,
        ),
      );

      // Failed: 2 photos, 3 videos
      for (int i = 0; i < 2; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo_failed_$i.jpg',
            mimeType: 'image/jpeg',
            dateTaken: now,
            fileSize: 1024 * 100,
            status: MediaItem.statusFailed,
            updatedAt: now,
          ),
        );
      }
      for (int i = 0; i < 3; i++) {
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/video_failed_$i.mp4',
            mimeType: 'video/mp4',
            dateTaken: now,
            fileSize: 1024 * 500,
            status: MediaItem.statusFailed,
            updatedAt: now,
          ),
        );
      }

      // 2. Verify counts
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusPending, isVideo: false),
        equals(3),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusPending, isVideo: true),
        equals(2),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusDone, isVideo: false),
        equals(4),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusDone, isVideo: true),
        equals(1),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusFailed, isVideo: false),
        equals(2),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusFailed, isVideo: true),
        equals(3),
      );

      // 3. Test pagination chunking (lazy generator simulation)
      final chunk1 = await DatabaseHelper.instance.getAllItems(
        statusFilter: MediaItem.statusDone,
        isVideo: false,
        limit: 2,
        offset: 0,
      );
      expect(chunk1.length, equals(2));

      final chunk2 = await DatabaseHelper.instance.getAllItems(
        statusFilter: MediaItem.statusDone,
        isVideo: false,
        limit: 2,
        offset: 2,
      );
      expect(chunk2.length, equals(2));
      expect(chunk1.first.filePath, isNot(equals(chunk2.first.filePath)));

      // 4. Test targeted retryAllFailed for specific media types
      final retriedPhotos = await DatabaseHelper.instance.retryAllFailed(isVideo: false);
      expect(retriedPhotos, equals(2));
      // Failed photos should now be 0, failed videos should still be 3
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusFailed, isVideo: false),
        equals(0),
      );
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusFailed, isVideo: true),
        equals(3),
      );

      final retriedVideos = await DatabaseHelper.instance.retryAllFailed(isVideo: true);
      expect(retriedVideos, equals(3));
      expect(
        await DatabaseHelper.instance.getItemCount(statusFilter: MediaItem.statusFailed, isVideo: true),
        equals(0),
      );
    });
  });

  group('LazyMediaListSheet Widget Tests', () {
    testWidgets('Renders LazyMediaListSheet with count and items', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await DatabaseHelper.instance.insert(
        MediaItem(
          filePath: '/storage/DCIM/Camera/IMG_001.jpg',
          mimeType: 'image/jpeg',
          dateTaken: now,
          fileSize: 1024 * 1024 * 2, // 2 MB
          status: MediaItem.statusPending,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    LazyMediaListSheet.show(
                      context,
                      title: 'Photos in Queue',
                      statusFilter: MediaItem.statusPending,
                      isVideo: false,
                      icon: Icons.photo_library_outlined,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Photos in Queue'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Count badge
      expect(find.text('IMG_001.jpg'), findsOneWidget);
      expect(find.text('2.0 MB'), findsOneWidget);
    });

    testWidgets('LazyMediaListSheet displays empty state when no items exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    LazyMediaListSheet.show(
                      context,
                      title: 'Failed Videos',
                      statusFilter: MediaItem.statusFailed,
                      isVideo: true,
                      icon: Icons.videocam_off_outlined,
                    );
                  },
                  child: const Text('Open Empty Sheet'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Empty Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Failed Videos'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // Count badge 0
      expect(find.text('No items found'), findsOneWidget);
      expect(find.text('Category is currently empty'), findsOneWidget);
    });
  });

  group('ActivityView Filter Tabs and Telemetry Tests', () {
    testWidgets('ActivityView renders Failed Photos & Failed Videos filter chips', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityView(onDataChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check filter chips exist
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
      expect(find.text('> 2 GB'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Failed Photos'), findsOneWidget);
      expect(find.text('Failed Videos'), findsOneWidget);

      // Check telemetry titles exist
      expect(find.text('PHOTOS IN QUEUE'), findsOneWidget);
      expect(find.text('VIDEOS IN QUEUE'), findsOneWidget);
      expect(find.text('PHOTOS SYNCED'), findsOneWidget);
      expect(find.text('VIDEOS SYNCED'), findsOneWidget);
      expect(find.text('FAILED PHOTOS'), findsOneWidget);
      expect(find.text('FAILED VIDEOS'), findsOneWidget);

      // Tap on 'PHOTOS IN QUEUE' telemetry tile to open lazy popup
      await tester.tap(find.text('PHOTOS IN QUEUE'));
      await tester.pumpAndSettle();

      expect(find.text('Photos in Queue'), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('Selecting Failed Photos filter displays dedicated section', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityView(onDataChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the 'Failed Photos' choice chip
      await tester.tap(find.text('Failed Photos'));
      await tester.pumpAndSettle();

      expect(find.text('Open Lazy Viewer (0)'), findsOneWidget);
      expect(find.text('No Failed Photos Detected'), findsOneWidget);
    });
  });
}
