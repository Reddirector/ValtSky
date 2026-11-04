import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/media_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static final Map<String, MediaItem> _webItems = {};
  static bool _inMemoryOverride = false;

  static void enableMemoryStoreForTesting() => _inMemoryOverride = true;
  static void clearMemoryStoreForTesting() => _webItems.clear();

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

  Future<int> update(MediaItem item) async {
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

  Future<List<MediaItem>> getAllItems({String? statusFilter}) async {
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      var items = _webItems.values.toList();
      if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
        items = items.where((e) => e.fileSize >= twoGigabytes).toList();
      } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        items = items.where((e) => e.status == statusFilter).toList();
      }
      items.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
      return items;
    }
    final db = await instance.database;
    final List<Map<String, dynamic>> maps;
    if (statusFilter == 'OVERSIZED' || statusFilter == '> 2 GB') {
      maps = await db.query(
        'media_items',
        where: 'fileSize >= ?',
        whereArgs: [twoGigabytes],
        orderBy: 'dateTaken DESC',
      );
    } else if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
      maps = await db.query(
        'media_items',
        where: 'status = ?',
        whereArgs: [statusFilter],
        orderBy: 'dateTaken DESC',
      );
    } else {
      maps = await db.query('media_items', orderBy: 'dateTaken DESC');
    }
    return maps.map((e) => MediaItem.fromMap(e)).toList();
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

  /// Atomically claims the next pending media item and marks it as UPLOADING
  Future<MediaItem?> claimNextPending() async {
    const int twoGigabytes = 2147483648;
    if (_useMemoryStore) {
      final pending = _webItems.values
          .where((e) => e.status == MediaItem.statusPending && e.fileSize < twoGigabytes)
          .toList();
      pending.sort((a, b) => a.dateTaken.compareTo(b.dateTaken));
      final item = pending.firstOrNull;
      if (item != null) {
        final updated = item.copyWith(
          status: MediaItem.statusUploading,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        _webItems[item.filePath] = updated;
        return updated;
      }
      return null;
    }
    final db = await instance.database;
    return await db.transaction((txn) async {
      final maps = await txn.query(
        'media_items',
        where: 'status = ? AND fileSize < ?',
        whereArgs: [MediaItem.statusPending, twoGigabytes],
        orderBy: 'dateTaken ASC',
        limit: 1,
      );
      if (maps.isEmpty) return null;
      final item = MediaItem.fromMap(maps.first);
      final updated = item.copyWith(
        status: MediaItem.statusUploading,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await txn.update(
        'media_items',
        {
          'status': MediaItem.statusUploading,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'filePath = ?',
        whereArgs: [item.filePath],
      );
      return updated;
    });
  }

  Future<int> getUploadingCount() async {
    if (_useMemoryStore) {
      return _webItems.values.where((e) => e.status == MediaItem.statusUploading).length;
    }
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'UPLOADING'")) ?? 0;
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

  Future<int> retryAllFailed() async {
    if (_useMemoryStore) {
      int count = 0;
      for (final item in _webItems.values) {
        if (item.status == MediaItem.statusFailed) {
          _webItems[item.filePath] = item.copyWith(status: MediaItem.statusPending, retryCount: 0);
          count++;
        }
      }
      return count;
    }
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending, 'retryCount': 0},
      where: 'status = ?',
      whereArgs: [MediaItem.statusFailed],
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

  Future<int> deleteAll() async {
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
