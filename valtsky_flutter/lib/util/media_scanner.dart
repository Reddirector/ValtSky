import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';

class MediaScanner {
  static Future<void> scanForNewMedia() async {
    // Request permission if needed
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) return;

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );
    
    for (var path in paths) {
      if (path.isAll) {
        // Scan last 100 items to be safe
        final List<AssetEntity> entities = await path.getAssetListRange(start: 0, end: 100);
        for (var entity in entities) {
          final file = await entity.file;
          if (file != null) {
            final exists = await DatabaseHelper.instance.exists(file.path);
            if (!exists) {
              final item = MediaItem(
                filePath: file.path,
                mimeType: entity.mimeType ?? 'image/jpeg',
                dateTaken: entity.createDateTime.millisecondsSinceEpoch,
                fileSize: await file.length(),
                status: MediaItem.statusPending,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );
              await DatabaseHelper.instance.insert(item);
            }
          }
        }
      }
    }
  }
}
