import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/media_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

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
    final db = await instance.database;
    return await db.insert('media_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> update(MediaItem item) async {
    final db = await instance.database;
    return await db.update(
      'media_items',
      item.toMap(),
      where: 'filePath = ?',
      whereArgs: [item.filePath],
    );
  }

  Future<MediaItem?> getItem(String path) async {
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

  Future<MediaItem?> getNextPending() async {
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ?',
      whereArgs: [MediaItem.statusPending],
      orderBy: 'dateTaken ASC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MediaItem.fromMap(maps.first);
    }
    return null;
  }

  Future<List<MediaItem>> getAllPending() async {
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'status = ?',
      whereArgs: [MediaItem.statusPending],
      orderBy: 'dateTaken ASC',
    );
    return maps.map((e) => MediaItem.fromMap(e)).toList();
  }

  Future<int> resetUploadingToPending() async {
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending},
      where: 'status = ?',
      whereArgs: [MediaItem.statusUploading],
    );
  }

  Future<int> getTotalCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM media_items')) ?? 0;
  }

  Future<int> getUploadedCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'DONE'")) ?? 0;
  }

  Future<int> getPendingCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'PENDING' OR status = 'UPLOADING'")) ?? 0;
  }

  Future<int> getFailedCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM media_items WHERE status = 'FAILED'")) ?? 0;
  }

  Stream<List<MediaItem>> getFailedItemsStream() async* {
    final db = await instance.database;
    // sqflite doesn't support streams natively, we would usually use a wrapper or manual triggers.
    // For now, this is a placeholder. In a real app, we'd use something like Watcher.
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
    final db = await instance.database;
    final maps = await db.query(
      'media_items',
      where: 'filePath = ?',
      whereArgs: [path],
    );
    return maps.isNotEmpty;
  }

  Future<int> retryAllFailed() async {
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending, 'retryCount': 0},
      where: 'status = ?',
      whereArgs: [MediaItem.statusFailed],
    );
  }

  Future<int> retrySingle(String path) async {
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusPending, 'retryCount': 0},
      where: 'filePath = ?',
      whereArgs: [path],
    );
  }

  Future<int> markAsManuallyDone(List<String> paths) async {
    final db = await instance.database;
    return await db.update(
      'media_items',
      {'status': MediaItem.statusDone, 'errorReason': 'Manually Uploaded'},
      where: 'filePath IN (${paths.map((e) => "'\$e'").join(',')})',
    );
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
    return await db.delete('media_items');
  }
}
