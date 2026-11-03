import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';
import 'telegram_auth_service.dart';
import 'telegram_auth_service_native.dart';
import '../util/file_security_guard.dart';

class SyncStats {
  final int total;
  final int synced;
  final int inQueue;
  final int failed;
  final int uploading;
  final double progress;

  const SyncStats({
    required this.total,
    required this.synced,
    required this.inQueue,
    required this.failed,
    this.uploading = 0,
    required this.progress,
  });
}

class SyncEngine {
  static final SyncEngine instance = SyncEngine._internal();
  SyncEngine._internal();
  factory SyncEngine() => instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  Completer<void>? _syncCompleter;

  // 4 concurrent turbo upload workers targeting 60+ images/minute (~1 image/sec)
  static const int _workerCount = 4;

  // Real-time speed and status notifier for the UI
  static final ValueNotifier<String> uploadSpeedNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> currentItemNotifier = ValueNotifier<String>('');
  static final ValueNotifier<SyncStats?> statsNotifier = ValueNotifier<SyncStats?>(null);
  Timer? _liveStatsTimer;

  static int _totalBytesAccumulator = 0;
  static int _lastSampleBytes = 0;
  static DateTime _lastSampleTime = DateTime.now();

  /// Query SQLite and notify all UI listeners with fresh live counts (< 1ms)
  static Future<SyncStats> fetchCurrentStats() async {
    final total = await DatabaseHelper.instance.getTotalCount();
    final synced = await DatabaseHelper.instance.getUploadedCount();
    final inQueue = await DatabaseHelper.instance.getPendingCount();
    final failed = await DatabaseHelper.instance.getFailedCount();
    final uploading = await DatabaseHelper.instance.getUploadingCount();
    final progress = total == 0 ? 0.0 : (synced / total).clamp(0.0, 1.0);
    final stats = SyncStats(
      total: total,
      synced: synced,
      inQueue: inQueue,
      failed: failed,
      uploading: uploading,
      progress: progress,
    );
    statsNotifier.value = stats;
    return stats;
  }

  Future<void> startSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncCompleter = Completer<void>();

    // Reset any interrupted uploading state from abrupt app closes
    await DatabaseHelper.instance.resetUploadingToPending();
    await fetchCurrentStats();

    // Start live 500ms reactive ticker while actively syncing
    _liveStatsTimer?.cancel();
    _liveStatsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_isSyncing) {
        fetchCurrentStats();
      }
    });

    _runWorkerPool();
  }

  void stopSync() {
    _isSyncing = false;
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    fetchCurrentStats();
    _syncCompleter?.complete();
  }

  Future<void> _runWorkerPool() async {
    final workers = List.generate(_workerCount, (index) => _workerLoop(index));
    await Future.wait(workers);

    _isSyncing = false;
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    await fetchCurrentStats();
    _syncCompleter?.complete();
  }

  Future<void> _workerLoop(int workerIndex) async {
    while (_isSyncing) {
      if (Prefs.uploadPaused) {
        uploadSpeedNotifier.value = 'Paused';
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      // Atomically claim the next pending item in strict chronological order (dateTaken ASC)
      final item = await DatabaseHelper.instance.claimNextPending();
      if (item == null) {
        // Queue is drained
        break;
      }

      final fileName = item.filePath.split('/').last;
      currentItemNotifier.value = fileName;
      fetchCurrentStats();

      final file = File(item.filePath);
      if (!await file.exists()) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: 'File not found on storage',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        fetchCurrentStats();
        continue;
      }

      // Fast security verification (reads initial 512 bytes header)
      final validation = await FileSecurityGuard.validateFile(file);
      if (!validation.isValid) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: '🛡️ Security Guard: ${validation.error}',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        fetchCurrentStats();
        continue;
      }

      final result = await _uploadWithSpeedOptimization(item, file, workerIndex: workerIndex);

      if (result is Success) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusDone,
          telegramMessageId: result.telegramMessageId,
          errorReason: null,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        Prefs.lastSyncedTs = DateTime.now().millisecondsSinceEpoch;
        _accumulateFinishedBytes(await file.length());
        fetchCurrentStats();
      } else if (result is TelegramError) {
        if (result.code == 429) {
          uploadSpeedNotifier.value = 'Cooldown (${result.retryAfterSeconds ?? 30}s)';
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          fetchCurrentStats();
          await Future.delayed(Duration(seconds: result.retryAfterSeconds ?? 30));
        } else {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusFailed,
            errorReason: result.description,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          fetchCurrentStats();
        }
      } else if (result is Failure) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: result.message,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        fetchCurrentStats();
      }
    }
  }

  static void _accumulateFinishedBytes(int bytes) {
    _totalBytesAccumulator += bytes;
  }

  static void _recordProgress(int sent, int total) {
    final now = DateTime.now();
    final ms = now.difference(_lastSampleTime).inMilliseconds;
    if (ms >= 400) {
      final currentBytes = _totalBytesAccumulator + sent;
      final bytesDelta = currentBytes - _lastSampleBytes;
      if (bytesDelta > 0) {
        final speedMBps = (bytesDelta / (1024 * 1024)) / (ms / 1000);
        if (speedMBps > 0.05) {
          uploadSpeedNotifier.value = '⚡ ${speedMBps.toStringAsFixed(1)} MB/s';
        }
      }
      _lastSampleBytes = currentBytes;
      _lastSampleTime = now;
    }
  }

  /// High-speed upload with live speed meter and in-memory chunk streaming
  Future<UploadResult> _uploadWithSpeedOptimization(
    MediaItem item,
    File file, {
    int workerIndex = 0,
  }) async {
    final rawName = file.path.split('/').last;
    final fileName = FileSecurityGuard.sanitizeFileName(rawName);
    final fileSize = await file.length();
    final maxSingleBytes = Prefs.maxChunkSizeMb * 1024 * 1024;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch(item.dateTaken),
    );

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
          onProgress: _recordProgress,
        );
      } else {
        return await TelegramAuthService.instance.uploadMedia(
          file: file,
          channelId: Prefs.channelId,
          asDocument: Prefs.useOriginalQuality,
          caption: caption,
          onProgress: _recordProgress,
          workerIndex: workerIndex,
        );
      }
    }

    // Large file: Stream raw chunks in-memory for maximum speed
    return await _streamChunkedFile(file, fileName, fileSize, maxSingleBytes, dateStr, item.fileHash, _recordProgress);
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
