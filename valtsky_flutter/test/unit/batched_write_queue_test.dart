import 'package:flutter_test/flutter_test.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';

void main() {
  setUp(() {
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('BatchedWriteQueue Tests', () {
    test('Enqueues item updates and provides instant read-through consistency', () async {
      final item = MediaItem(
        filePath: '/test/photo1.jpg',
        fileHash: 'hash_photo1',
        mimeType: 'image/jpeg',
        dateTaken: 1000,
        fileSize: 1024,
        status: MediaItem.statusPending,
        updatedAt: 1000,
      );
      await DatabaseHelper.instance.insert(item);

      // Verify initial state
      var retrieved = await DatabaseHelper.instance.getItem(item.filePath);
      expect(retrieved?.status, equals(MediaItem.statusPending));

      // Enqueue update to DONE without immediate flush
      final doneItem = item.copyWith(status: MediaItem.statusDone, telegramMessageId: 12345);
      DatabaseHelper.instance.enqueueUpdate(doneItem, immediate: false);

      // Read-through should immediately see DONE
      retrieved = await DatabaseHelper.instance.getItem(item.filePath);
      expect(retrieved?.status, equals(MediaItem.statusDone));
      expect(retrieved?.telegramMessageId, equals(12345));

      // Explicit flush commits to backing store
      await DatabaseHelper.instance.flushPendingUpdates();
      retrieved = await DatabaseHelper.instance.getItem(item.filePath);
      expect(retrieved?.status, equals(MediaItem.statusDone));
    });

    test('Batched threshold flushes automatically on 10 items', () async {
      for (int i = 0; i < 12; i++) {
        final item = MediaItem(
          filePath: '/test/item_$i.jpg',
          fileHash: 'hash_$i',
          mimeType: 'image/jpeg',
          dateTaken: 1000 + i,
          fileSize: 1024,
          status: MediaItem.statusPending,
          updatedAt: 1000 + i,
        );
        await DatabaseHelper.instance.insert(item);
        final doneItem = item.copyWith(status: MediaItem.statusDone);
        DatabaseHelper.instance.enqueueUpdate(doneItem, immediate: false);
      }

      final counts = await DatabaseHelper.instance.getAggregatedCounts();
      expect(counts['synced'], equals(12));
    });

    test('deleteItem and deleteItems evict staged items from write queue', () async {
      final item = MediaItem(
        filePath: '/test/delete_me.jpg',
        fileHash: 'hash_del',
        mimeType: 'image/jpeg',
        dateTaken: 2000,
        fileSize: 1024,
        status: MediaItem.statusPending,
        updatedAt: 2000,
      );
      await DatabaseHelper.instance.insert(item);

      // Enqueue an update to write queue
      final updated = item.copyWith(status: MediaItem.statusUploading);
      DatabaseHelper.instance.enqueueUpdate(updated, immediate: false);

      expect(await DatabaseHelper.instance.getItem(item.filePath), isNotNull);

      // Delete item
      await DatabaseHelper.instance.deleteItem(item.filePath);

      // Must be evicted from write queue as well
      expect(await DatabaseHelper.instance.getItem(item.filePath), isNull);
    });
  });
}
