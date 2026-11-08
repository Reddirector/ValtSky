import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/media_item.dart';
import '../models/media_breakdown.dart';
import 'batched_write_queue.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static final Map<String, MediaItem> _webItems = {};
  static bool _inMemoryOverride = false;

  late final BatchedWriteQueue _writeQueue = BatchedWriteQueue(
    onCommitBatch: _commitBatchToStorage,
  );

  static void enableMemoryStoreForTesting() => _inMemoryOverride = true;
  static void clearMemoryStoreForTesting() {
    _webItems.clear();
    instance._writeQueue.clear();
  }

  static bool get _useMemoryStore {
    if (kIsWeb || _inMemoryOverride) return true;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return true;
    } catch (_) {
      return true;
    }
    return false;
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('valtsky.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA synchronous = NORMAL;');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE media_items (
        filePath TEXT PRIMARY KEY,
        fileHash TEXT,
        mimeType TEXT,
        dateTaken INTEGER,
        fileSize INTEGER,
        status TEXT,
        telegramMessageId INTEGER,
        errorReason TEXT,
        retryCount INTEGER,
        updatedAt INTEGER
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_fileHash ON media_items (fileHash)');
  }

  Future<int> insert(MediaItem item) async {
    if (_useMemoryStore) {
      if (!_webItems.containsKey(item.filePath)) {
        _webItems[item.filePath] = item;
        return 1;
      }
      return 0;
    }
    final db = await instance.database;
    return await db.insert('media_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> insertBatch(List<MediaItem> items) async {
    if (items.isEmpty) return 0;
    if (_useMemoryStore) {
      int inserted = 0;
      for (final item in items) {
        if (!_webItems.containsKey(item.filePath)) {
          _webItems[item.filePath] = item;
          inserted++;
        }
      }
      return inserted;
    }
    final db = await instance.database;
    int inserted = 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        batch.insert('media_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final results = await batch.commit(noResult: false);
      inserted = results.where((r) => r is int && r > 0).length;
    });
    return inserted;
  }

  Future<void> _commitBatchToStorage(List<MediaItem> items) async {
    if (_useMemoryStore) {
      for (final item in items) {
        _webItems[item.filePath] = item;
      }
      return;
    }
    final db = await instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        batch.update(
          'media_items',
          item.toMap(),
          where: 'filePath = ?',
          whereArgs: [item.filePath],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Enqueue an item update into the in-memory batch.
  void enqueueUpdate(MediaItem item, {bool immediate = false}) =>
      _writeQueue.enqueue(item, immediate: immediate);

  /// Flushes all staged updates in a single atomic SQLite transaction.
  Future<void> flushPendingUpdates() => _writeQueue.flush();

  Future<int> updateBatch(List<MediaItem> items) async {
    if (items.isEmpty) return 0;
    if (_useMemoryStore) {
      for (final item in items) {
        _webItems[item.filePath] = item;
      }
      return items.length;
    }
    final db = await instance.database;
    int updated = 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        batch.update(
          'media_items',
          item.toMap(),
          where: 'filePath = ?',
          whereArgs: [item.filePath],
        );
      }
      final results = await batch.commit(noResult: false);
      updated = results.length;
    });
    return updated;
  }

  Future<int> update(MediaItem item) async {
    _writeQueue.remove(item.filePath);
    if (_useMemoryStore) {
      _webItems[item.filePath] = item;
      return 1;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      item.toMap(),
      where: 'filePath = ?',
      whereArgs: [item.filePath],
    );
  }

  Future<MediaItem?> getItem(String path) async {
    final staged = _writeQueue.getItem(path);
    if (staged != null) return staged;

    if (_useMemoryStore) {
      return _webItems[path];
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'filePath = ?',
      whereArgs: [path],
    );

    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  Future<MediaItem?> getItemByHash(String hash) async {
    final staged = _writeQueue.getItemByHash(hash);
    if (staged != null) return staged;

    if (_useMemoryStore) {
      for (final item in _webItems.values) {
        if (item.fileHash == hash) return item;
      }
      return null;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'fileHash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (maps.isNotEmpty) return MediaItem.fromMap(maps.first);
    return null;
  }

  Future<List<MediaItem>> getAllItems({
    String? statusFilter,
    bool? isVideo,
    int? limit,
    int? offset,
  }) async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      var items = _webItems.values.toList();
      if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
        items = items.where((e) => e.fileSize >= twoGigabytes).toList();
      } else if (statusFilter == 'FAILED_PHOTOS') {
        items = items.where((e) => e.status == MediaItem.statusFailed && !e.isVideo).toList();
      } else if (statusFilter == 'FAILED_VIDEOS') {
        items = items.where((e) => e.status == MediaItem.statusFailed && e.isVideo).toList();
      } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        items = items.where((e) => e.status == statusFilter).toList();
      }

      if (isVideo != null) {
        items = items.where((e) => isVideo ? e.isVideo : !e.isVideo).toList();
      }

      items.sort((a, b) {
        final c = b.dateTaken.compareTo(a.dateTaken);
        if (c != 0) return c;
        return b.filePath.compareTo(a.filePath);
      });
      if (offset != null) items = items.skip(offset).toList();
      if (limit != null) items = items.take(limit).toList();
      return items;
    }

    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
      whereClauses.add('fileSize >= ?');
      whereArgs.add(twoGigabytes);
    } else if (statusFilter == 'FAILED_PHOTOS') {
      whereClauses.add('status = ?');
      whereArgs.add(MediaItem.statusFailed);
      whereClauses.add("COALESCE(mimeType, '') NOT LIKE '%video%'");
    } else if (statusFilter == 'FAILED_VIDEOS') {
      whereClauses.add('status = ?');
      whereArgs.add(MediaItem.statusFailed);
      whereClauses.add("mimeType LIKE '%video%'");
    } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter);
    }

    if (isVideo != null) {
      if (isVideo) {
        whereClauses.add("mimeType LIKE '%video%'");
      } else {
        whereClauses.add("COALESCE(mimeType, '') NOT LIKE '%video%'");
      }
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'media_items',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'dateTaken DESC, filePath DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((e) => MediaItem.fromMap(e)).toList();
  }

  Future<int> getItemCount({
    String? statusFilter,
    bool? isVideo,
  }) async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      var items = _webItems.values.toList();
      if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
        items = items.where((e) => e.fileSize >= twoGigabytes).toList();
      } else if (statusFilter == 'FAILED_PHOTOS') {
        items = items.where((e) => e.status == MediaItem.statusFailed && !e.isVideo).toList();
      } else if (statusFilter == 'FAILED_VIDEOS') {
        items = items.where((e) => e.status == MediaItem.statusFailed && e.isVideo).toList();
      } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        items = items.where((e) => e.status == statusFilter).toList();
      }
      if (isVideo != null) {
        items = items.where((e) => isVideo ? e.isVideo : !e.isVideo).toList();
      }
      return items.length;
    }

    final db = await instance.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
      whereClauses.add('fileSize >= ?');
      whereArgs.add(twoGigabytes);
    } else if (statusFilter == 'FAILED_PHOTOS') {
      whereClauses.add('status = ?');
      whereArgs.add(MediaItem.statusFailed);
      whereClauses.add("COALESCE(mimeType, '') NOT LIKE '%video%'");
    } else if (statusFilter == 'FAILED_VIDEOS') {
      whereClauses.add('status = ?');
      whereArgs.add(MediaItem.statusFailed);
      whereClauses.add("mimeType LIKE '%video%'");
    } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter);
    }

    if (isVideo != null) {
      if (isVideo) {
        whereClauses.add("mimeType LIKE '%video%'");
      } else {
        whereClauses.add("COALESCE(mimeType, '') NOT LIKE '%video%'");
      }
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM media_items ${whereString != null ? 'WHERE $whereString' : ''}',
      whereArgs.isNotEmpty ? whereArgs : null,
    );
    if (res.isNotEmpty && res.first['count'] != null) {
      return (res.first['count'] as num).toInt();
    }
    return 0;
  }

  Future<int> getOversizedCount({int minSizeBytes = 2147483648}) async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.fileSize >= minSizeBytes).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM media_items WHERE fileSize >= ?',
      [minSizeBytes],
    )) ?? 0;
  }

  Future<MediaItem?> getNextPending() async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final pending = _webItems.values
          .where((e) => e.status == MediaItem.statusPending && e.fileSize < twoGigabytes)
          .toList();
      pending.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      return pending.firstOrNull;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ? AND fileSize < ?',
      whereArgs: [MediaItem.statusPending, twoGigabytes],
      orderBy: 'dateTaken ASC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  /// Atomically claims a batch of pending photo items (excluding videos)
  Future<List<MediaItem>> claimPendingPhotoBatch({int limit = 16}) async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final items = _webItems.values
          .where((e) =>
              e.status == MediaItem.statusPending &&
              e.fileSize < twoGigabytes &&
              !e.mimeType.contains('video'))
          .toList();
      items.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      final updatedBatch = <MediaItem>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in items.take(limit)) {
        final updated = item.copyWith(
          status: MediaItem.statusUploading,
          updatedAt: now,
        );
        _webItems[item.filePath] = updated;
        updatedBatch.add(updated);
      }
      return updatedBatch;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ? AND fileSize < ? AND mimeType NOT LIKE ?',
      whereArgs: [MediaItem.statusPending, twoGigabytes, '%video%'],
      orderBy: 'dateTaken ASC',
      limit: limit,
    );
    if (maps.isEmpty) return [];
    final items = maps.map((m) => MediaItem.fromMap(m)).toList();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedItems = <MediaItem>[];
    for (final item in items) {
      final updated = item.copyWith(
        status: MediaItem.statusUploading,
        updatedAt: now,
      );
      updatedItems.add(updated);
      batch.update(
        'media_items',
        {
          'status': MediaItem.statusUploading,
          'updatedAt': now,
        },
        where: 'filePath = ?',
        whereArgs: [item.filePath],
      );
    }
    await batch.commit(noResult: true);
    return updatedItems;
  }

  /// Atomically claims a batch of pending video items
  Future<List<MediaItem>> claimPendingVideoBatch({int limit = 8}) async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final items = _webItems.values
          .where((e) =>
              e.status == MediaItem.statusPending &&
              e.fileSize < twoGigabytes &&
              e.mimeType.contains('video'))
          .toList();
      items.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      final updatedBatch = <MediaItem>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in items.take(limit)) {
        final updated = item.copyWith(
          status: MediaItem.statusUploading,
          updatedAt: now,
        );
        _webItems[item.filePath] = updated;
        updatedBatch.add(updated);
      }
      return updatedBatch;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ? AND fileSize < ? AND mimeType LIKE ?',
      whereArgs: [MediaItem.statusPending, twoGigabytes, '%video%'],
      orderBy: 'dateTaken ASC',
      limit: limit,
    );
    if (maps.isEmpty) return [];
    final items = maps.map((m) => MediaItem.fromMap(m)).toList();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedItems = <MediaItem>[];
    for (final item in items) {
      final updated = item.copyWith(
        status: MediaItem.statusUploading,
        updatedAt: now,
      );
      updatedItems.add(updated);
      batch.update(
        'media_items',
        {
          'status': MediaItem.statusUploading,
          'updatedAt': now,
        },
        where: 'filePath = ?',
        whereArgs: [item.filePath],
      );
    }
    await batch.commit(noResult: true);
    return updatedItems;
  }

  Future<List<MediaItem>> claimPendingBatch({int limit = 32}) async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final items = _webItems.values
          .where((e) => e.status == MediaItem.statusPending && e.fileSize < twoGigabytes)
          .toList();
      items.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      final updatedBatch = <MediaItem>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in items.take(limit)) {
        final updated = item.copyWith(
          status: MediaItem.statusUploading,
          updatedAt: now,
        );
        _webItems[item.filePath] = updated;
        updatedBatch.add(updated);
      }
      return updatedBatch;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ? AND fileSize < ?',
      whereArgs: [MediaItem.statusPending, twoGigabytes],
      orderBy: 'dateTaken ASC',
      limit: limit,
    );
    if (maps.isEmpty) return [];
    final items = maps.map((m) => MediaItem.fromMap(m)).toList();
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedItems = <MediaItem>[];
    for (final item in items) {
      final updated = item.copyWith(
        status: MediaItem.statusUploading,
        updatedAt: now,
      );
      updatedItems.add(updated);
      batch.update(
        'media_items',
        {
          'status': MediaItem.statusUploading,
          'updatedAt': now,
        },
        where: 'filePath = ?',
        whereArgs: [item.filePath],
      );
    }
    await batch.commit(noResult: true);
    return updatedItems;
  }

  /// Atomically claims the next pending media item and marks it as UPLOADING
  Future<MediaItem?> claimNextPending() async {
    final batch = await claimPendingBatch(limit: 1);
    return batch.isNotEmpty ? batch.first : null;
  }

  Future<MediaBreakdown> getMediaBreakdown() async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      int pendingPhotos = 0;
      int pendingVideos = 0;
      int syncedPhotos = 0;
      int syncedVideos = 0;
      int failedPhotos = 0;
      int failedVideos = 0;
      int oversized = 0;

      for (final item in _webItems.values) {
        final isVid = item.isVideo;
        final isOversized = item.fileSize >= twoGigabytes;
        final isQueued = (item.status == MediaItem.statusPending || item.status == MediaItem.statusUploading);

        if (isQueued && isOversized) {
          oversized++;
        } else if (isQueued) {
          if (isVid) {
            pendingVideos++;
          } else {
            pendingPhotos++;
          }
        } else if (item.status == MediaItem.statusDone) {
          if (isVid) {
            syncedVideos++;
          } else {
            syncedPhotos++;
          }
        } else if (item.status == MediaItem.statusFailed) {
          if (isVid) {
            failedVideos++;
          } else {
            failedPhotos++;
          }
        }
      }

      return MediaBreakdown(
        totalCount: _webItems.length,
        pendingPhotos: pendingPhotos,
        pendingVideos: pendingVideos,
        syncedPhotos: syncedPhotos,
        syncedVideos: syncedVideos,
        failedPhotos: failedPhotos,
        failedVideos: failedVideos,
        oversizedCount: oversized,
      );
    }
    try {
      final db = await instance.database;
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalCount,
          SUM(CASE WHEN (status = 'PENDING' OR status = 'UPLOADING') AND fileSize < 2147483648 AND COALESCE(mimeType, '') NOT LIKE '%video%' THEN 1 ELSE 0 END) as pendingPhotos,
          SUM(CASE WHEN (status = 'PENDING' OR status = 'UPLOADING') AND fileSize < 2147483648 AND COALESCE(mimeType, '') LIKE '%video%' THEN 1 ELSE 0 END) as pendingVideos,
          SUM(CASE WHEN status = 'DONE' AND COALESCE(mimeType, '') NOT LIKE '%video%' THEN 1 ELSE 0 END) as syncedPhotos,
          SUM(CASE WHEN status = 'DONE' AND COALESCE(mimeType, '') LIKE '%video%' THEN 1 ELSE 0 END) as syncedVideos,
          SUM(CASE WHEN status = 'FAILED' AND COALESCE(mimeType, '') NOT LIKE '%video%' THEN 1 ELSE 0 END) as failedPhotos,
          SUM(CASE WHEN status = 'FAILED' AND COALESCE(mimeType, '') LIKE '%video%' THEN 1 ELSE 0 END) as failedVideos,
          SUM(CASE WHEN (status = 'PENDING' OR status = 'UPLOADING') AND fileSize >= 2147483648 THEN 1 ELSE 0 END) as oversizedCount
        FROM media_items
      ''');
      if (rows.isNotEmpty) {
        final r = rows.first;
        return MediaBreakdown(
          totalCount: (r['totalCount'] as num?)?.toInt() ?? 0,
          pendingPhotos: (r['pendingPhotos'] as num?)?.toInt() ?? 0,
          pendingVideos: (r['pendingVideos'] as num?)?.toInt() ?? 0,
          syncedPhotos: (r['syncedPhotos'] as num?)?.toInt() ?? 0,
          syncedVideos: (r['syncedVideos'] as num?)?.toInt() ?? 0,
          failedPhotos: (r['failedPhotos'] as num?)?.toInt() ?? 0,
          failedVideos: (r['failedVideos'] as num?)?.toInt() ?? 0,
          oversizedCount: (r['oversizedCount'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return const MediaBreakdown();
  }

  /// Clears all pending or currently uploading items from the queue.
  Future<int> clearPendingQueue() async {
    if (_useMemoryStore) {
      final pendingKeys = _webItems.entries
          .where((e) => e.value.status == MediaItem.statusPending || e.value.status == MediaItem.statusUploading)
          .map((e) => e.key)
          .toList();
      for (final key in pendingKeys) {
        _webItems.remove(key);
      }
      return pendingKeys.length;
    }
    final db = await instance.database;
    return await db.delete(
      'media_items',
      where: 'status = ? OR status = ?',
      whereArgs: [MediaItem.statusPending, MediaItem.statusUploading],
    );
  }

  Future<Map<String, int>> getAggregatedCounts() async {
    if (_writeQueue.isNotEmpty) {
      await flushPendingUpdates();
    }
    if (_useMemoryStore) {
      final total = _webItems.length;
      final synced = _webItems.values.where((e) => e.status == MediaItem.statusDone).length;
      final inQueue = _webItems.values.where((e) => e.status == MediaItem.statusPending).length;
      final failed = _webItems.values.where((e) => e.status == MediaItem.statusFailed).length;
      final uploading = _webItems.values.where((e) => e.status == MediaItem.statusUploading).length;
      return {
        'total': total,
        'synced': synced,
        'inQueue': inQueue,
        'failed': failed,
        'uploading': uploading,
      };
    }
    try {
      final db = await instance.database;
      final rows = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN status = 'DONE' THEN 1 ELSE 0 END) as synced,
          SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as inQueue,
          SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
          SUM(CASE WHEN status = 'UPLOADING' THEN 1 ELSE 0 END) as uploading
        FROM media_items
      ''');
      if (rows.isNotEmpty) {
        final row = rows.first;
        return {
          'total': (row['total'] as int?) ?? 0,
          'synced': (row['synced'] as int?) ?? 0,
          'inQueue': (row['inQueue'] as int?) ?? 0,
          'failed': (row['failed'] as int?) ?? 0,
          'uploading': (row['uploading'] as int?) ?? 0,
        };
      }
    } catch (_) {}
    return {'total': 0, 'synced': 0, 'inQueue': 0, 'failed': 0, 'uploading': 0};
  }

  Future<int> getUploadingCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusUploading).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'UPLOADING'")) ?? 0;
  }

  Future<Set<String>> getAllFilePathsSet() async {
    if (_useMemoryStore) {
      return _webItems.keys.toSet();
    }
    try {
      final db = await instance.database;
      final rows = await db.rawQuery('SELECT filePath FROM media_items');
      return rows.map((r) => r['filePath'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<int> getLatestDateTaken() async {
    if (_useMemoryStore) {
      if (_webItems.isEmpty) return 0;
      return _webItems.values.map((e) => e.dateTaken).reduce((a, b) => a > b ? a : b);
    }
    try {
      final db = await instance.database;
      final result = await db.rawQuery('SELECT MAX(dateTaken) as latest FROM media_items');
      if (result.isNotEmpty && result.first['latest'] != null) {
        return result.first['latest'] as int;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<MediaItem>> getAllPending() async {
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final pending = _webItems.values
          .where((e) => e.status == MediaItem.statusPending && e.fileSize < twoGigabytes)
          .toList();
      pending.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      return pending;
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ? AND fileSize < ?',
      whereArgs: [MediaItem.statusPending, twoGigabytes],
      orderBy: 'dateTaken ASC',
    );
    return maps.map((e) => MediaItem.fromMap(e)).toList();
  }

  Future<int> resetUploadingToPending() async {
    if (_useMemoryStore) {
      int count = 0;
      for (final item in _webItems.values) {
        if (item.status == MediaItem.statusUploading) {
          _webItems[item.filePath] = item.copyWith(status: MediaItem.statusPending);
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending},
      where: 'status = ?',
      whereArgs: [MediaItem.statusUploading],
    );
  }

  Future<int> getTotalCount() async {
    if (_useMemoryStore) {
      return _webItems.length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM media_items')) ?? 0;
  }

  Future<int> getUploadedCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusDone).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'DONE'")) ?? 0;
  }

  Future<int> getPendingCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusPending || e.status == MediaItem.statusUploading).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'PENDING' OR status = 'UPLOADING'")) ?? 0;
  }

  Future<int> getFailedCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusFailed).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'FAILED'")) ?? 0;
  }

  Future<List<MediaItem>> getFailedItems({int limit = 10}) async {
    if (_useMemoryStore) {
      final items = _webItems.values.where((e) => e.status == MediaItem.statusFailed).toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.take(limit).toList();
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ?',
      whereArgs: [MediaItem.statusFailed],
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return maps.map((e) => MediaItem.fromMap(e)).toList();
  }

  Stream<List<MediaItem>> getFailedItemsStream() async* {
    if (_useMemoryStore) {
      while (true) {
        yield _webItems.values.where((e) => e.status == MediaItem.statusFailed).toList();
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    final db = await instance.database;
    while (true) {
      final maps = await db.query(
        'media_items',
        where: 'status = ?',
        whereArgs: [MediaItem.statusFailed],
        orderBy: 'updatedAt DESC',
      );
      yield maps.map((e) => MediaItem.fromMap(e)).toList();
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<bool> exists(String path) async {
    if (_useMemoryStore) {
      return _webItems.containsKey(path);
    }
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'filePath = ?',
      whereArgs: [path],
    );
    return maps.isNotEmpty;
  }

  Future<int> retryAllFailed({bool? isVideo}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_useMemoryStore) {
      int count = 0;
      for (final item in _webItems.values) {
        if (item.status == MediaItem.statusFailed) {
          if (isVideo != null && item.isVideo != isVideo) continue;
          _webItems[item.filePath] = item.copyWith(
            status: MediaItem.statusPending,
            retryCount: 0,
            errorReason: null,
            updatedAt: now,
          );
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    String where = 'status = ?';
    List<dynamic> whereArgs = [MediaItem.statusFailed];
    if (isVideo != null) {
      if (isVideo) {
        where += " AND mimeType LIKE '%video%'";
      } else {
        where += " AND COALESCE(mimeType, '') NOT LIKE '%video%'";
      }
    }
    return await db.update(
      'media_items',
      {
        'status': MediaItem.statusPending,
        'retryCount': 0,
        'errorReason': null,
        'updatedAt': now,
      },
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Stash all currently failed items to shelve them out of the error queue
  Future<int> stashAllFailed() async {
    if (_useMemoryStore) {
      int count = 0;
      for (final item in _webItems.values) {
        if (item.status == MediaItem.statusFailed) {
          _webItems[item.filePath] = item.copyWith(
            status: MediaItem.statusStashed,
            errorReason: 'Stashed by user',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {
        'status': MediaItem.statusStashed,
        'errorReason': 'Stashed by user',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'status = ?',
      whereArgs: [MediaItem.statusFailed],
    );
  }

  /// Stash a single failed item
  Future<int> stashSingle(String path) async {
    if (_useMemoryStore) {
      final item = _webItems[path];
      if (item != null) {
        _webItems[path] = item.copyWith(
          status: MediaItem.statusStashed,
          errorReason: 'Stashed by user',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        return 1;
      }
      return 0;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {
        'status': MediaItem.statusStashed,
        'errorReason': 'Stashed by user',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'filePath = ?',
      whereArgs: [path],
    );
  }

  /// Restore all stashed items back to pending queue
  Future<int> restoreAllStashed() async {
    if (_useMemoryStore) {
      int count = 0;
      for (final item in _webItems.values) {
        if (item.status == MediaItem.statusStashed) {
          _webItems[item.filePath] = item.copyWith(
            status: MediaItem.statusPending,
            errorReason: null,
            retryCount: 0,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {
        'status': MediaItem.statusPending,
        'errorReason': null,
        'retryCount': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'status = ?',
      whereArgs: [MediaItem.statusStashed],
    );
  }

  Future<int> getStashedCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusStashed).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'STASHED'")) ?? 0;
  }

  Future<int> retrySingle(String path) async {
    if (_useMemoryStore) {
      final item = _webItems[path];
      if (item != null) {
        _webItems[path] = item.copyWith(status: MediaItem.statusPending, retryCount: 0);
        return 1;
      }
      return 0;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending, 'retryCount': 0},
      where: 'filePath = ?',
      whereArgs: [path],
    );
  }

  Future<int> markAsManuallyDone(List<String> paths) async {
    if (_useMemoryStore) {
      int count = 0;
      for (final p in paths) {
        final item = _webItems[p];
        if (item != null) {
          _webItems[p] = item.copyWith(status: MediaItem.statusDone, errorReason: 'Manually Uploaded');
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusDone, 'errorReason': 'Manually Uploaded'},
      where: 'filePath IN (${paths.map((e) => "'$e'").join(',')})',
    );
  }

  /// Delete a single media item by its file path (removes it from queue/index)
  Future<int> deleteItem(String path) async {
    _writeQueue.remove(path);
    if (_useMemoryStore) {
      return _webItems.remove(path) != null ? 1 : 0;
    }
    final db = await instance.database;
    return await db.delete(
      'media_items',
      where: 'filePath = ?',
      whereArgs: [path],
    );
  }

  /// Batch delete media items by file paths
  Future<int> deleteItems(List<String> paths) async {
    if (paths.isEmpty) return 0;
    for (final p in paths) {
      _writeQueue.remove(p);
    }
    if (_useMemoryStore) {
      int count = 0;
      for (final p in paths) {
        if (_webItems.remove(p) != null) count++;
      }
      return count;
    }
    final db = await instance.database;
    int totalDeleted = 0;
    const chunkSize = 500;
    for (int i = 0; i < paths.length; i += chunkSize) {
      final end = (i + chunkSize < paths.length) ? i + chunkSize : paths.length;
      final chunk = paths.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      totalDeleted += await db.delete(
        'media_items',
        where: 'filePath IN ($placeholders)',
        whereArgs: chunk,
      );
    }
    return totalDeleted;
  }

  Future<int> deleteAll() async {
    _writeQueue.clear();
    if (_useMemoryStore) {
      final count = _webItems.length;
      _webItems.clear();
      return count;
    }
    try {
      final db = await instance.database;
      return await db.delete('media_items');
    } catch (_) {
      return 0;
    }
  }
}
