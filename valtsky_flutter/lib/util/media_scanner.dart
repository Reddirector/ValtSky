import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';

class MediaScanner {
  @visibleForTesting
  static Future<int> Function({bool forceFull})? scanHookForTesting;

  /// Timestamp of the last completed scan — avoids redundant full scans when
  /// the app is resumed within a short window (< 120 seconds).
  static DateTime _lastScanCompleted = DateTime.fromMillisecondsSinceEpoch(0);

  /// Minimum interval between automatic scans (2 minutes).
  /// Manual pull-to-refresh or forceFull bypasses this.
  static const Duration _scanCooldown = Duration(seconds: 120);

  /// Resets the scan cooldown timer. Used in tests to allow back-to-back scans.
  @visibleForTesting
  static void resetScanCooldown() {
    _lastScanCompleted = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Scans device storage for new photos & videos in strict chronological order.
  /// If [forceFull] is false and items already exist in the database, performs a blazing-fast
  /// incremental scan using [DatabaseHelper.getLatestDateTaken].
  /// Returns the number of newly discovered and queued items.
  static Future<int> scanForNewMedia({bool forceFull = false}) async {
    if (scanHookForTesting != null) {
      return await scanHookForTesting!(forceFull: forceFull);
    }

    // Skip redundant scans if one completed recently (unless forced)
    if (!forceFull) {
      final elapsed = DateTime.now().difference(_lastScanCompleted);
      if (elapsed < _scanCooldown) {
        debugPrint('[MediaScanner] Skipping scan — last completed ${elapsed.inSeconds}s ago (cooldown: ${_scanCooldown.inSeconds}s)');
        return 0;
      }
    }

    // Always purge obsolete dummy/mock records on scan
    await DatabaseHelper.instance.purgeDummyMockItems();

    if (kIsWeb) {
      return await _scanMediaViaBridge(forceFull: forceFull);
    }

    // Desktop platforms (Linux, macOS, Windows) scan directories directly via dart:io
    int result = 0;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        result = await _scanDesktopDirectories(forceFull: forceFull);
        _lastScanCompleted = DateTime.now();
        return result;
      }
    } catch (_) {}

    result = await _scanMobilePhotoManager(forceFull: forceFull);
    _lastScanCompleted = DateTime.now();
    return result;
  }

  static Future<int> _scanMediaViaBridge({bool forceFull = false}) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get('http://localhost:8088/api/scan_local_media');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final itemsRaw = data['items'] as List<dynamic>? ?? [];
        if (itemsRaw.isEmpty) return 0;

        final existingPaths = await DatabaseHelper.instance.getAllFilePathsSet();
        final List<MediaItem> pendingBatch = [];
        final now = DateTime.now().millisecondsSinceEpoch;

        for (final itemMap in itemsRaw) {
          if (itemMap is! Map) continue;
          final filePath = itemMap['filePath'] as String? ?? '';
          if (filePath.isEmpty || existingPaths.contains(filePath)) continue;

          final fileSize = (itemMap['fileSize'] as num?)?.toInt() ?? 0;
          final dateTaken = (itemMap['dateTaken'] as num?)?.toInt() ?? now;
          final mimeType = itemMap['mimeType'] as String? ?? 'image/jpeg';

          pendingBatch.add(MediaItem(
            filePath: filePath,
            mimeType: mimeType,
            dateTaken: dateTaken,
            fileSize: fileSize,
            status: MediaItem.statusPending,
            updatedAt: now,
          ));
          existingPaths.add(filePath);
        }

        if (pendingBatch.isNotEmpty) {
          await DatabaseHelper.instance.insertBatch(pendingBatch);
          debugPrint('[MediaScanner] Web indexed ${pendingBatch.length} real files from host disk via bridge');
        }
        return pendingBatch.length;
      }
    } catch (e) {
      debugPrint('[MediaScanner] Web bridge scan fallback error: $e');
    }
    return 0;
  }

  static Future<int> _scanDesktopDirectories({bool forceFull = false}) async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (home.isEmpty) return 0;

    final candidateDirs = [
      Directory('$home/Pictures'),
      Directory('$home/Downloads'),
      Directory('$home/Videos'),
      Directory('$home/Documents'),
      Directory('$home/Desktop'),
    ];

    const supportedExts = {
      '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic',
      '.mp4', '.mov', '.mkv', '.webm', '.avi'
    };

    final existingPaths = await DatabaseHelper.instance.getAllFilePathsSet();
    final List<MediaItem> pendingBatch = [];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final dir in candidateDirs) {
      if (!dir.existsSync()) continue;
      try {
        await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
          if (entity is! File) continue;
          final filePath = entity.path;
          final segments = filePath.split(RegExp(r'[/\\]'));
          if (segments.any((seg) => seg.startsWith('.') || seg == 'node_modules' || seg == 'build' || seg == '.dart_tool' || seg == 'target' || seg == 'cache')) {
            continue;
          }
          final dotIdx = filePath.lastIndexOf('.');
          if (dotIdx == -1) continue;
          final ext = filePath.substring(dotIdx).toLowerCase();
          if (!supportedExts.contains(ext)) continue;
          if (existingPaths.contains(filePath)) continue;

          try {
            final stat = entity.statSync();
            final isVideo = ['.mp4', '.mov', '.mkv', '.webm', '.avi'].contains(ext);
            final mimeType = isVideo
                ? (ext == '.mov' ? 'video/quicktime' : 'video/mp4')
                : (ext == '.png' ? 'image/png' : (ext == '.webp' ? 'image/webp' : 'image/jpeg'));

            pendingBatch.add(MediaItem(
              filePath: filePath,
              mimeType: mimeType,
              dateTaken: stat.modified.millisecondsSinceEpoch,
              fileSize: stat.size,
              status: MediaItem.statusPending,
              updatedAt: now,
            ));
            existingPaths.add(filePath);
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[MediaScanner] Desktop scan dir error (${dir.path}): $e');
      }
    }

    if (pendingBatch.isNotEmpty) {
      // Sort chronologically ascending
      pendingBatch.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      await DatabaseHelper.instance.insertBatch(pendingBatch);
      debugPrint('[MediaScanner] Desktop indexed ${pendingBatch.length} real files');
    }
    return pendingBatch.length;
  }

  static Future<int> _scanMobilePhotoManager({bool forceFull = false}) async {
    // Request permission safely without crashing if called from background service isolate
    try {
      final PermissionState ps = await PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );
      if (!ps.hasAccess) {
        final PermissionState requested = await PhotoManager.requestPermissionExtend();
        if (!requested.hasAccess) {
          debugPrint('[MediaScanner] Storage/Media permission not granted (state: $requested)');
          return 0;
        }
      }
    } catch (e) {
      debugPrint('[MediaScanner] Permission check exception: $e');
    }

    // Incremental scan support: only query assets newer than our newest indexed item
    final int latestDateTaken = forceFull ? 0 : await DatabaseHelper.instance.getLatestDateTaken();

    // Configure filter to sort strictly from OLDEST to NEWEST (asc: true)
    final FilterOptionGroup filterOption;
    if (latestDateTaken > 0) {
      filterOption = FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: true),
        ],
        createTimeCond: DateTimeCond(
          min: DateTime.fromMillisecondsSinceEpoch(latestDateTaken - 60000),
          max: DateTime.now().add(const Duration(days: 1)),
        ),
      );
    } else {
      filterOption = FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: true),
        ],
      );
    }

    final List<AssetPathEntity> paths;
    try {
      paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: filterOption,
      );
    } catch (e) {
      debugPrint('[MediaScanner] PhotoManager not available on this platform/test runner: $e');
      return 0;
    }

    if (paths.isEmpty) {
      debugPrint('[MediaScanner] No asset paths returned by PhotoManager');
      return 0;
    }

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

    final existingPaths = await DatabaseHelper.instance.getAllFilePathsSet();
    int processedItemsCounter = 0;

    for (final path in albumsToScan) {
      final totalCount = await path.assetCountAsync;
      if (totalCount == 0) continue;
      const pageSize = 150;

      for (int start = 0; start < totalCount; start += pageSize) {
        final List<AssetEntity> entities = await path.getAssetListRange(
          start: start,
          end: (start + pageSize > totalCount) ? totalCount : (start + pageSize),
        );

        for (final entity in entities) {
          processedItemsCounter++;
          if (processedItemsCounter % 10 == 0) {
            // Yield to the event loop every 10 items to prevent UI jank
            await Future.delayed(Duration.zero);
          }

          final file = await entity.originFile ?? await entity.file;
          if (file != null) {
            final pathStr = file.path;
            if (processedInThisRun.contains(pathStr) || existingPaths.contains(pathStr)) {
              continue;
            }
            processedInThisRun.add(pathStr);
            existingPaths.add(pathStr);

            final item = MediaItem(
              filePath: pathStr,
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

    if (pendingBatch.isNotEmpty) {
      await DatabaseHelper.instance.insertBatch(pendingBatch);
      pendingBatch.clear();
    }

    debugPrint('[MediaScanner] Scan complete. Added $newlyAddedCount new items to sync queue.');
    return newlyAddedCount;
  }
}
