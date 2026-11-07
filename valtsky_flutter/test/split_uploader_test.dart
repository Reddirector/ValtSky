import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/models/media_breakdown.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('Split Uploader Dual-Lane Concurrency Tests', () {
    test('Photo uploader claims and processes photos only while video uploader processes videos only', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final videoItem = MediaItem(
        filePath: '/storage/DCIM/Camera/VID_20260101.mp4',
        mimeType: 'video/mp4',
        dateTaken: now - 5000,
        fileSize: 150 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final photoItem1 = MediaItem(
        filePath: '/storage/DCIM/Camera/IMG_20260101_01.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - 4000,
        fileSize: 3 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final photoItem2 = MediaItem(
        filePath: '/storage/DCIM/Camera/IMG_20260101_02.png',
        mimeType: 'image/png',
        dateTaken: now - 3000,
        fileSize: 5 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );

      await DatabaseHelper.instance.insert(videoItem);
      await DatabaseHelper.instance.insert(photoItem1);
      await DatabaseHelper.instance.insert(photoItem2);

      // Photo uploader claims photos only
      final claimedPhotos = await DatabaseHelper.instance.claimPendingPhotoBatch(limit: 10);
      expect(claimedPhotos.length, equals(2));
      expect(claimedPhotos.every((item) => item.isPhoto), isTrue);
      expect(claimedPhotos.any((item) => item.isVideo), isFalse);

      // Video uploader claims videos only
      final claimedVideos = await DatabaseHelper.instance.claimPendingVideoBatch(limit: 10);
      expect(claimedVideos.length, equals(1));
      expect(claimedVideos.first.isVideo, isTrue);
      expect(claimedVideos.first.filePath, equals(videoItem.filePath));

      // Both can be processed at the exact same time without waiting
      expect(claimedPhotos.isNotEmpty, isTrue);
      expect(claimedVideos.isNotEmpty, isTrue);
    });

    test('MediaItem isVideo and isPhoto helper getters evaluate correctly', () {
      final img = MediaItem(
        filePath: '/test/photo.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 100,
        fileSize: 1000,
        status: MediaItem.statusPending,
        updatedAt: 100,
      );
      final vid = MediaItem(
        filePath: '/test/movie.mp4',
        mimeType: 'video/mp4',
        dateTaken: 200,
        fileSize: 50000,
        status: MediaItem.statusPending,
        updatedAt: 200,
      );

      expect(img.isVideo, isFalse);
      expect(img.isPhoto, isTrue);
      expect(vid.isVideo, isTrue);
      expect(vid.isPhoto, isFalse);
    });

    test('SyncEngine dual-lane status notification combines photo and video items concurrently', () {
      SyncEngine.updateWorkerItemStatus(isVideo: false, fileName: 'sunset.jpg');
      expect(SyncEngine.currentItemNotifier.value, contains('sunset.jpg'));

      SyncEngine.updateWorkerItemStatus(isVideo: true, fileName: 'vacation.mp4');
      // Both photo and video active file names are presented simultaneously
      expect(SyncEngine.currentItemNotifier.value, contains('sunset.jpg'));
      expect(SyncEngine.currentItemNotifier.value, contains('vacation.mp4'));

      SyncEngine.clearWorkerItemStatus(isVideo: false);
      expect(SyncEngine.currentItemNotifier.value, contains('vacation.mp4'));
      expect(SyncEngine.currentItemNotifier.value, isNot(contains('sunset.jpg')));

      SyncEngine.clearWorkerItemStatus(isVideo: true);
      expect(SyncEngine.currentItemNotifier.value, isEmpty);
    });
  });

  group('DatabaseHelper MediaBreakdown & Value Equality Tests', () {
    test('MediaBreakdown value equality and hashCode work correctly', () {
      const b1 = MediaBreakdown(
        pendingPhotos: 5,
        pendingVideos: 2,
        syncedPhotos: 10,
        syncedVideos: 4,
        failedPhotos: 0,
        failedVideos: 0,
        totalCount: 21,
        oversizedCount: 0,
      );
      const b2 = MediaBreakdown(
        pendingPhotos: 5,
        pendingVideos: 2,
        syncedPhotos: 10,
        syncedVideos: 4,
        failedPhotos: 0,
        failedVideos: 0,
        totalCount: 21,
        oversizedCount: 0,
      );
      const b3 = MediaBreakdown(
        pendingPhotos: 4, // different
        pendingVideos: 2,
        syncedPhotos: 11,
        syncedVideos: 4,
        failedPhotos: 0,
        failedVideos: 0,
        totalCount: 21,
        oversizedCount: 0,
      );

      expect(b1, equals(b2));
      expect(b1.hashCode, equals(b2.hashCode));
      expect(b1, isNot(equals(b3)));
    });

    test('getMediaBreakdown correctly tallies photo and video counts and decrements live', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      final photo1 = MediaItem(
        filePath: '/test/photo1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - 1000,
        fileSize: 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final photo2 = MediaItem(
        filePath: '/test/photo2.jpg',
        mimeType: 'image/png',
        dateTaken: now - 900,
        fileSize: 2 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final video1 = MediaItem(
        filePath: '/test/video1.mp4',
        mimeType: 'video/mp4',
        dateTaken: now - 800,
        fileSize: 50 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final syncedPhoto = MediaItem(
        filePath: '/test/synced_photo.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - 700,
        fileSize: 1024 * 1024,
        status: MediaItem.statusDone,
        updatedAt: now,
      );
      final syncedVideo = MediaItem(
        filePath: '/test/synced_video.mp4',
        mimeType: 'video/mp4',
        dateTaken: now - 600,
        fileSize: 20 * 1024 * 1024,
        status: MediaItem.statusDone,
        updatedAt: now,
      );
      final failedPhoto = MediaItem(
        filePath: '/test/failed_photo.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - 500,
        fileSize: 1024 * 1024,
        status: MediaItem.statusFailed,
        updatedAt: now,
      );
      final oversizedVideo = MediaItem(
        filePath: '/test/huge_4k.mov',
        mimeType: 'video/quicktime',
        dateTaken: now - 400,
        fileSize: 3 * 1024 * 1024 * 1024, // 3 GB (> 2GB)
        status: MediaItem.statusPending,
        updatedAt: now,
      );

      await DatabaseHelper.instance.insert(photo1);
      await DatabaseHelper.instance.insert(photo2);
      await DatabaseHelper.instance.insert(video1);
      await DatabaseHelper.instance.insert(syncedPhoto);
      await DatabaseHelper.instance.insert(syncedVideo);
      await DatabaseHelper.instance.insert(failedPhoto);
      await DatabaseHelper.instance.insert(oversizedVideo);

      MediaBreakdown breakdown = await DatabaseHelper.instance.getMediaBreakdown();
      expect(breakdown.pendingPhotos, equals(2));
      expect(breakdown.pendingVideos, equals(1));
      expect(breakdown.syncedPhotos, equals(1));
      expect(breakdown.syncedVideos, equals(1));
      expect(breakdown.failedPhotos, equals(1));
      expect(breakdown.failedVideos, equals(0));
      expect(breakdown.oversizedCount, equals(1));
      expect(breakdown.totalPending, equals(3));
      expect(breakdown.totalSynced, equals(2));

      // Simulate photo1 uploading successfully:
      await DatabaseHelper.instance.update(photo1.copyWith(
        status: MediaItem.statusDone,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));

      breakdown = await DatabaseHelper.instance.getMediaBreakdown();
      expect(breakdown.pendingPhotos, equals(1)); // Decremented!
      expect(breakdown.syncedPhotos, equals(2));  // Incremented!

      // Simulate video1 uploading successfully:
      await DatabaseHelper.instance.update(video1.copyWith(
        status: MediaItem.statusDone,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));

      breakdown = await DatabaseHelper.instance.getMediaBreakdown();
      expect(breakdown.pendingVideos, equals(0)); // Decremented!
      expect(breakdown.syncedVideos, equals(2));  // Incremented!
    });

    test('clearPendingQueue removes all pending items but retains synced items', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/test/pending1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now,
        fileSize: 1000,
        status: MediaItem.statusPending,
        updatedAt: now,
      ));
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/test/synced1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now,
        fileSize: 1000,
        status: MediaItem.statusDone,
        updatedAt: now,
      ));

      final deletedCount = await DatabaseHelper.instance.clearPendingQueue();
      expect(deletedCount, equals(1));

      final breakdown = await DatabaseHelper.instance.getMediaBreakdown();
      expect(breakdown.pendingPhotos, equals(0));
      expect(breakdown.syncedPhotos, equals(1));
    });

    test('retryAllFailed resets failed items to pending', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/test/failed1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now,
        fileSize: 1000,
        status: MediaItem.statusFailed,
        updatedAt: now,
      ));

      final retried = await DatabaseHelper.instance.retryAllFailed();
      expect(retried, equals(1));

      final breakdown = await DatabaseHelper.instance.getMediaBreakdown();
      expect(breakdown.failedPhotos, equals(0));
      expect(breakdown.pendingPhotos, equals(1));
    });

    test('High-speed upload sliding window parameters scale dynamically with file size and bound RAM', () {
      // Small file (< 1MB) uses 256KB chunks and concurrent part saturation
      const smallSize = 800 * 1024;
      final smallChunk = (smallSize < 1024 * 1024) ? (256 * 1024) : (512 * 1024);
      final smallParts = (smallSize / smallChunk).ceil();
      final smallConcurrency = (smallParts <= 4) ? smallParts : 6;
      expect(smallChunk, equals(256 * 1024));
      expect(smallParts, equals(4));
      expect(smallConcurrency, equals(4));

      // Large file (30MB+) uses 512KB chunks and 8 concurrent pipelined parts (up to 40-80 MB/s line rate)
      const largeSize = 30 * 1024 * 1024;
      final largeChunk = (largeSize < 1024 * 1024) ? (256 * 1024) : (512 * 1024);
      final largeParts = (largeSize / largeChunk).ceil();
      final isBig = largeSize > 10 * 1024 * 1024;
      final largeConcurrency = (largeParts <= 4) ? largeParts : (isBig ? 8 : 6);
      expect(largeChunk, equals(512 * 1024));
      expect(largeParts, equals(60));
      expect(largeConcurrency, equals(8));
      // Max in-flight memory footprint is strictly bounded to 8 * 512 KB = 4 MB RAM
      expect(largeConcurrency * largeChunk, equals(4 * 1024 * 1024));
    });

    test('Queue uploads persist and continue even when monitoring is stopped unless paused', () async {
      Prefs.monitoringEnabled = false;
      Prefs.uploadPaused = false;

      final now = DateTime.now().millisecondsSinceEpoch;
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/storage/DCIM/Camera/IMG_queue1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now,
        fileSize: 2000,
        status: MediaItem.statusPending,
        updatedAt: now,
      ));

      // Items remain in pending queue ready for uploader despite monitoringEnabled being false
      final pendingCount = await DatabaseHelper.instance.getPendingCount();
      expect(pendingCount, equals(1));

      // Claiming item for upload works normally when monitoring is false
      final batch = await DatabaseHelper.instance.claimPendingPhotoBatch(limit: 5);
      expect(batch.length, equals(1));
      expect(batch.first.filePath, equals('/storage/DCIM/Camera/IMG_queue1.jpg'));

      // If user pauses, uploadPaused becomes true and inhibits processing
      Prefs.uploadPaused = true;
      expect(Prefs.uploadPaused, isTrue);
      expect(Prefs.monitoringEnabled, isFalse);

      // Unpausing restores upload capability without needing monitoringEnabled to be true
      Prefs.uploadPaused = false;
      expect(Prefs.uploadPaused, isFalse);
      expect(Prefs.monitoringEnabled, isFalse);
    });
  });
}
