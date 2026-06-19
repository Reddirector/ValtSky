import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';
import '../util/file_utils.dart';

class SyncEngine {
  static const int maxTelegramSize = 50 * 1024 * 1024; // 50MB
  
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  Future<void> startSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncCompleter = Completer<void>();
    _processQueue();
  }

  void stopSync() {
    _isSyncing = false;
    _syncCompleter?.complete();
  }

  Future<void> _processQueue() async {
    while (_isSyncing) {
      if (Prefs.uploadPaused) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }

      final item = await DatabaseHelper.instance.getNextPending();
      if (item == null) {
        _isSyncing = false;
        break;
      }

      // Check network
      // (Placeholder for network connectivity check)

      final file = File(item.filePath);
      if (!await file.exists()) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: 'File not found',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        continue;
      }

      // Update status to uploading
      await DatabaseHelper.instance.update(item.copyWith(status: MediaItem.statusUploading));

      // Calculate hash if missing
      if (item.fileHash == null) {
        final hash = await FileUtils.getFileHash(file);
        if (hash != null) {
          final existing = await DatabaseHelper.instance.getItemByHash(hash);
          if (existing != null && existing.status == MediaItem.statusDone) {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusDone,
              fileHash: hash,
              telegramMessageId: existing.telegramMessageId,
              errorReason: 'Deduplicated (Hash Match)',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            continue;
          }
          item.fileHash = hash;
        }
      }

      final result = await _handleLargeAndUpload(item, file);

      if (result is Success) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusDone,
          telegramMessageId: result.telegramMessageId,
          errorReason: null,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        Prefs.lastSyncedTs = DateTime.now().millisecondsSinceEpoch;
      } else if (result is TelegramError) {
        if (result.code == 429) { // Rate limit
          await Future.delayed(Duration(seconds: result.retryAfterSeconds ?? 30));
          await DatabaseHelper.instance.update(item.copyWith(status: MediaItem.statusPending));
        } else {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusFailed,
            errorReason: result.description,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      } else if (result is Failure) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: result.message,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    _isSyncing = false;
  }

  Future<UploadResult> _handleLargeAndUpload(MediaItem item, File file) async {
    if (item.fileSize > maxTelegramSize && item.mimeType.startsWith('image')) {
      final compressed = await _compressImage(file);
      if (compressed != null) {
        final result = await TelegramApi.sendMedia(
          Prefs.botToken,
          Prefs.channelId,
          compressed,
          false,
          'Compressed due to size limit',
        );
        return result;
      }
    }

    return await TelegramApi.sendMedia(
      Prefs.botToken,
      Prefs.channelId,
      file,
      Prefs.useOriginalQuality,
      null,
    );
  }

  Future<File?> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      final compressedBytes = img.encodeJpg(image, quality: 70);
      final tempFile = File('\${Directory.systemTemp.path}/temp_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e) {
      return null;
    }
  }
}

extension on DatabaseHelper {
  Future<MediaItem?> getItemByHash(String hash) async {
    final db = await database;
    final maps = await db.query(
      'media_items',
      where: 'fileHash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (maps.isNotEmpty) return MediaItem.fromMap(maps.first);
    return null;
  }
}
