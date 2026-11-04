import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';

class MediaScanner {
  /// Scans device storage for new photos & videos in strict chronological order.
  /// Returns the number of newly discovered and queued items.
  static Future<int> scanForNewMedia() async {
    if (kIsWeb) {
      if (await DatabaseHelper.instance.getTotalCount() == 0) {
        final now = DateTime.now();
        // Insert in chronological order: Oldest -> Newest
        await DatabaseHelper.instance.insert(MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261025_001.jpg',
          mimeType: 'image/jpeg',
          dateTaken: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch, // Oldest (7 days ago)
          fileSize: 3420100,
          status: MediaItem.statusDone,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        await DatabaseHelper.instance.insert(MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/IMG_20261028_002.jpg',
          mimeType: 'image/jpeg',
          dateTaken: now.subtract(const Duration(days: 3)).millisecondsSinceEpoch, // Middle (3 days ago)
          fileSize: 2854300,
          status: MediaItem.statusPending,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        await DatabaseHelper.instance.insert(MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_003.mp4',
          mimeType: 'video/mp4',
          dateTaken: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch, // Newest (1 hour ago)
          fileSize: 54100200,
          status: MediaItem.statusPending, // Set to pending so chunking can process it!
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        // Add 2.85 GB Oversized 4K Master Video (held for manual 4-click upload)
        await DatabaseHelper.instance.insert(MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/VID_20261101_4K60_CINEMATIC.mov',
          mimeType: 'video/quicktime',
          dateTaken: now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
          fileSize: 2854300000, // 2.85 GB (> 2GB Bot API threshold)
          status: MediaItem.statusPending,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        return 4;
      }
      return 0;
    }

    // Request permission if needed (handles full access and Android 14 limited access)
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        debugPrint('[MediaScanner] Storage/Media permission not granted (state: $ps)');
        return 0;
      }
    } catch (e) {
      debugPrint('[MediaScanner] Permission check exception: $e');
    }

    // Configure filter to sort strictly from OLDEST to NEWEST (asc: true)
    final filterOption = FilterOptionGroup(
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: true),
      ],
    );

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: filterOption,
    );

    if (paths.isEmpty) {
      debugPrint('[MediaScanner] No asset paths returned by PhotoManager');
      return 0;
    }

    // Determine target albums:
    // If an album with isAll is present, scanning it covers the entire device gallery.
    // If OEM returns discrete albums (Recent, Camera, WhatsApp, etc.), scan all of them.
    AssetPathEntity? allAlbum;
    for (final p in paths) {
      if (p.isAll) {
        allAlbum = p;
        break;
      }
    }

    final albumsToScan = allAlbum != null ? [allAlbum] : paths;
    int newlyAddedCount = 0;
    final Set<String> processedInThisRun = {};
    final List<MediaItem> pendingBatch = [];

    for (final path in albumsToScan) {
      final totalCount = await path.assetCountAsync;
      const pageSize = 150;

      for (int start = 0; start < totalCount; start += pageSize) {
        final List<AssetEntity> entities = await path.getAssetListRange(
          start: start,
          end: (start + pageSize > totalCount) ? totalCount : (start + pageSize),
        );

        for (final entity in entities) {
          final file = await entity.file;
          if (file != null) {
            if (processedInThisRun.contains(file.path)) continue;
            processedInThisRun.add(file.path);

            final exists = await DatabaseHelper.instance.exists(file.path);
            if (!exists) {
              final item = MediaItem(
                filePath: file.path,
                mimeType: entity.mimeType ?? (entity.type == AssetType.video ? 'video/mp4' : 'image/jpeg'),
                dateTaken: entity.createDateTime.millisecondsSinceEpoch,
                fileSize: await file.length(),
                status: MediaItem.statusPending,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );
              pendingBatch.add(item);
              newlyAddedCount++;

              if (pendingBatch.length >= 100) {
                await DatabaseHelper.instance.insertBatch(pendingBatch);
                pendingBatch.clear();
              }
            }
          }
        }
      }
    }

    if (pendingBatch.isNotEmpty) {
      await DatabaseHelper.instance.insertBatch(pendingBatch);
      pendingBatch.clear();
    }

    debugPrint('[MediaScanner] Scan complete. Added $newlyAddedCount new items to sync queue.');
    return newlyAddedCount;
  }
}
