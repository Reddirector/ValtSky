import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('Split Uploader Dual-Lane Claiming Tests', () {
    test('claimPendingPhotoBatch claims only images and ignores videos', () async {
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

      // Photos should be claimed even though video is older and at the front of chronological order
      final claimedPhotos = await DatabaseHelper.instance.claimPendingPhotoBatch(limit: 10);
      expect(claimedPhotos.length, equals(2));
      expect(claimedPhotos.any((item) => item.isVideo), isFalse);
      expect(claimedPhotos.map((e) => e.filePath), containsAll([photoItem1.filePath, photoItem2.filePath]));

      // Status should be marked UPLOADING for claimed photos, but video remains PENDING
      final dbVideo = await DatabaseHelper.instance.getItem(videoItem.filePath);
      expect(dbVideo?.status, equals(MediaItem.statusPending));
    });

    test('claimPendingVideoBatch claims only video items and ignores photos', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final photoItem = MediaItem(
        filePath: '/storage/DCIM/Camera/IMG_photo.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now - 1000,
        fileSize: 2 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );
      final videoItem = MediaItem(
        filePath: '/storage/DCIM/Camera/VID_video.mp4',
        mimeType: 'video/mp4',
        dateTaken: now,
        fileSize: 80 * 1024 * 1024,
        status: MediaItem.statusPending,
        updatedAt: now,
      );

      await DatabaseHelper.instance.insert(photoItem);
      await DatabaseHelper.instance.insert(videoItem);

      final claimedVideos = await DatabaseHelper.instance.claimPendingVideoBatch(limit: 10);
      expect(claimedVideos.length, equals(1));
      expect(claimedVideos.first.filePath, equals(videoItem.filePath));
      expect(claimedVideos.first.isVideo, isTrue);

      final dbPhoto = await DatabaseHelper.instance.getItem(photoItem.filePath);
      expect(dbPhoto?.status, equals(MediaItem.statusPending));
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

    test('SyncEngine dual-lane status notification combines photo and video items', () {
      SyncEngine.updateWorkerItemStatus(isVideo: false, fileName: 'sunset.jpg');
      expect(SyncEngine.currentItemNotifier.value, contains('sunset.jpg'));

      SyncEngine.updateWorkerItemStatus(isVideo: true, fileName: 'vacation.mp4');
      expect(SyncEngine.currentItemNotifier.value, contains('sunset.jpg'));
      expect(SyncEngine.currentItemNotifier.value, contains('vacation.mp4'));

      SyncEngine.clearWorkerItemStatus(isVideo: false);
      expect(SyncEngine.currentItemNotifier.value, contains('vacation.mp4'));
      expect(SyncEngine.currentItemNotifier.value, isNot(contains('sunset.jpg')));

      SyncEngine.clearWorkerItemStatus(isVideo: true);
      expect(SyncEngine.currentItemNotifier.value, isEmpty);
    });
  });
}
