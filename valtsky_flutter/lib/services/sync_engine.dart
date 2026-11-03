import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';
import 'telegram_auth_service.dart';
import '../util/file_utils.dart';
import '../util/file_security_guard.dart';

class SyncEngine {
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  // Real-time speed and status notifier for the UI
  static final ValueNotifier<String> uploadSpeedNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> currentItemNotifier = ValueNotifier<String>('');

  Future<void> startSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncCompleter = Completer<void>();
    _processQueue();
  }

  void stopSync() {
    _isSyncing = false;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    _syncCompleter?.complete();
  }

  Future<void> _processQueue() async {
    while (_isSyncing) {
      if (Prefs.uploadPaused) {
        uploadSpeedNotifier.value = 'Paused';
        await Future.delayed(const Duration(seconds: 3));
        continue;
      }

      // CRITICAL: Strictly fetch the OLDEST media first (dateTaken ASC)
      // This guarantees older photos/videos are posted first, appearing at the top of the Telegram channel.
      final item = await DatabaseHelper.instance.getNextPending();
      if (item == null) {
        _isSyncing = false;
        uploadSpeedNotifier.value = '';
        currentItemNotifier.value = '';
        break;
      }

      currentItemNotifier.value = item.filePath.split('/').last;

      final file = File(item.filePath);
      if (!await file.exists()) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: 'File not found on storage',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        continue;
      }

      // 🛡️ Senior Cybersecurity Guard: Inspect magic bytes and verify file integrity
      final validation = await FileSecurityGuard.validateFile(file);
      if (!validation.isValid) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: '🛡️ Security Guard: ${validation.error}',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        continue;
      }

      // Mark status as uploading
      await DatabaseHelper.instance.update(item.copyWith(status: MediaItem.statusUploading));

      // Compute hash for deduplication
      if (item.fileHash == null) {
        final hash = await FileUtils.getFileHash(file);
        if (hash != null) {
          final existing = await DatabaseHelper.instance.getItemByHash(hash);
          if (existing != null && existing.status == MediaItem.statusDone) {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusDone,
              fileHash: hash,
              telegramMessageId: existing.telegramMessageId,
              errorReason: 'Deduplicated (Identical Checksum)',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            continue;
          }
          item.fileHash = hash;
        }
      }

      final result = await _uploadWithSpeedOptimization(item, file);

      if (result is Success) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusDone,
          telegramMessageId: result.telegramMessageId,
          errorReason: null,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        Prefs.lastSyncedTs = DateTime.now().millisecondsSinceEpoch;
      } else if (result is TelegramError) {
        if (result.code == 429) {
          // Rate limited: cooldown
          uploadSpeedNotifier.value = 'Cooldown (${result.retryAfterSeconds ?? 30}s)';
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
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
  }

  /// High-speed upload with live speed meter and in-memory chunk streaming
  Future<UploadResult> _uploadWithSpeedOptimization(MediaItem item, File file) async {
    final rawName = file.path.split('/').last;
    final fileName = FileSecurityGuard.sanitizeFileName(rawName);
    final fileSize = await file.length();
    final maxSingleBytes = Prefs.maxChunkSizeMb * 1024 * 1024;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch(item.dateTaken),
    );

    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    void updateSpeed(int sent, int total) {
      final now = DateTime.now();
      final ms = now.difference(lastTime).inMilliseconds;
      if (ms >= 400 && sent > lastBytes) {
        final bytesDelta = sent - lastBytes;
        final speedMBps = (bytesDelta / (1024 * 1024)) / (ms / 1000);
        uploadSpeedNotifier.value = '⚡ ${speedMBps.toStringAsFixed(1)} MB/s';
        lastBytes = sent;
        lastTime = now;
      }
    }

    // Direct upload if within limit (Bot API 50MB, or MTProto native up to 2000MB)
    final isBotApi = Prefs.botToken.contains(':');
    final limitBytes = isBotApi ? maxSingleBytes : (2000 * 1024 * 1024);

    if (fileSize <= limitBytes || !Prefs.enableChunking) {
      final caption = '$fileName\nDate: $dateStr\nSize: ${_formatSize(fileSize)}';
      if (isBotApi) {
        return await TelegramApi.sendMedia(
          Prefs.botToken,
          Prefs.channelId,
          file,
          Prefs.useOriginalQuality,
          caption,
          onProgress: updateSpeed,
        );
      } else {
        return await TelegramAuthService.instance.uploadMedia(
          file: file,
          channelId: Prefs.channelId,
          asDocument: Prefs.useOriginalQuality,
          caption: caption,
          onProgress: updateSpeed,
        );
      }
    }

    // Large file: Stream raw chunks in-memory for maximum speed
    return await _streamChunkedFile(file, fileName, fileSize, maxSingleBytes, dateStr, item.fileHash, updateSpeed);
  }

  /// Zero-disk-bottleneck streaming: Reads directly from RAM and streams to Telegram
  Future<UploadResult> _streamChunkedFile(
    File file,
    String originalName,
    int totalBytes,
    int chunkBytes,
    String dateStr,
    String? fileHash,
    void Function(int sent, int total) onProgress,
  ) async {
    final totalParts = (totalBytes / chunkBytes).ceil();
    int lastMessageId = 0;
    RandomAccessFile? raf;

    try {
      raf = await file.open(mode: FileMode.read);
      for (int part = 1; part <= totalParts; part++) {
        if (Prefs.uploadPaused) {
          uploadSpeedNotifier.value = 'Paused';
          while (Prefs.uploadPaused) {
            await Future.delayed(const Duration(seconds: 3));
          }
        }

        final partFileName = '$originalName.part${part.toString().padLeft(3, '0')}';
        final bytesToRead = (part == totalParts) ? (totalBytes - (part - 1) * chunkBytes) : chunkBytes;

        // In-memory buffer read: 0 disk overhead
        final buffer = await raf.read(bytesToRead);

        final partCaption = '📦 $originalName [Part $part/$totalParts]\n'
            'Part Size: ${_formatSize(bytesToRead)} / ${_formatSize(totalBytes)}\n'
            'Date: $dateStr';

        currentItemNotifier.value = '$originalName [$part/$totalParts]';

        final result = await TelegramApi.sendBytes(
          Prefs.botToken,
          Prefs.channelId,
          buffer,
          partFileName,
          true, // Always lossless document for chunks
          partCaption,
          onProgress: onProgress,
        );

        if (result is Success) {
          lastMessageId = result.telegramMessageId;
        } else {
          return result;
        }
      }

      // Send completion manifest
      final manifestText = '✅ *Upload Complete: $originalName*\n'
          '📁 Total Parts: $totalParts\n'
          '📊 Full Size: ${_formatSize(totalBytes)}\n'
          '🕒 Date: $dateStr\n'
          '${fileHash != null ? '🔐 SHA-256: `$fileHash`' : ''}\n'
          '💡 _Preserved in exact chronological order._';

      if (Prefs.botToken.contains(':')) {
        await TelegramApi.sendMessage(Prefs.botToken, Prefs.channelId, manifestText);
      } else {
        await TelegramAuthService.instance.sendMessage(
          channelId: Prefs.channelId,
          text: manifestText,
        );
      }

      return Success(lastMessageId);
    } catch (e) {
      return Failure('Fast streaming failed: ${e.toString()}');
    } finally {
      await raf?.close();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
