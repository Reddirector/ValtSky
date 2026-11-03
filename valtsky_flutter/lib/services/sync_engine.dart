import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';
import 'telegram_auth_service.dart';
import '../util/file_security_guard.dart';

enum SyncEngineStatus {
  idle,             // No active sync; waiting
  active,           // Actively uploading with worker pool
  paused,           // Paused by user
  offline,          // Internet connection lost; auto-reconnecting
  rateLimited,      // Coordinated Telegram flood wait with live countdown
  sessionExpired,   // Telegram auth key revoked/expired; user action required
  permissionDenied, // Gallery or storage access denied
  restarting,       // Engine undergoing clean self-restart & reset
}

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
  static const int maxItemRetries = 3;

  // Global Engine Status & Diagnostic Notifiers
  static final ValueNotifier<SyncEngineStatus> engineStatusNotifier =
      ValueNotifier<SyncEngineStatus>(SyncEngineStatus.idle);
  static final ValueNotifier<String> engineStatusMessageNotifier =
      ValueNotifier<String>('');
  static final ValueNotifier<int> rateLimitSecondsRemainingNotifier =
      ValueNotifier<int>(0);

  // Real-time speed and status notifier for the UI
  static final ValueNotifier<String> uploadSpeedNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> currentItemNotifier = ValueNotifier<String>('');
  static final ValueNotifier<SyncStats?> statsNotifier = ValueNotifier<SyncStats?>(null);
  Timer? _liveStatsTimer;

  static int _totalBytesAccumulator = 0;
  static int _lastSampleBytes = 0;
  static DateTime _lastSampleTime = DateTime.now();

  static DateTime? _rateLimitUntil;
  static Timer? _rateLimitTimer;

  // ──────────────────────────────────────────────────────────────────────────
  // FAILURE CLASSIFIERS & HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Fast connectivity check via Google DNS & Telegram DNS
  static Future<bool> hasInternetConnection() async {
    if (kIsWeb) return true;
    try {
      final lookup = await InternetAddress.lookup('dns.google').timeout(const Duration(seconds: 3));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}
    try {
      final lookup = await InternetAddress.lookup('telegram.org').timeout(const Duration(seconds: 3));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  /// Determines whether an error string represents an OS or socket network interruption
  static bool isNetworkError(dynamic error) {
    if (error == null) return false;
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('handshakeexception') ||
        msg.contains('timeoutexception') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('no route to host') ||
        msg.contains('software caused connection abort') ||
        msg.contains('broken pipe') ||
        msg.contains('os error');
  }

  /// Determines whether a Telegram response indicates authentication failure
  static bool isSessionExpiredError(int? code, String message) {
    if (code == 401) return true;
    final msg = message.toUpperCase();
    return msg.contains('AUTH_KEY_UNREGISTERED') ||
        msg.contains('SESSION_REVOKED') ||
        msg.contains('SESSION_EXPIRED') ||
        msg.contains('USER_DEACTIVATED') ||
        msg.contains('AUTH_KEY_INVALID');
  }

  /// Determines whether an error is Telegram rate limiting (420 / 429)
  static bool isRateLimitError(int? code, String message) {
    if (code == 420 || code == 429) return true;
    final msg = message.toUpperCase();
    return msg.contains('FLOOD_WAIT') || msg.contains('SLOWMODE_WAIT');
  }

  /// Extracts the wait duration in seconds from FLOOD_WAIT_X messages
  static int extractFloodWaitSeconds(String message, [int? fallback]) {
    final match = RegExp(r'FLOOD_WAIT_(\d+)').firstMatch(message);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? fallback ?? 30;
    }
    return fallback ?? 30;
  }

  /// Checks if error represents Telegram channel permission missing
  static bool isChannelPermissionError(int? code, String message) {
    if (code == 403) return true;
    final msg = message.toUpperCase();
    return msg.contains('CHAT_ADMIN_REQUIRED') ||
        msg.contains('CHAT_WRITE_FORBIDDEN') ||
        msg.contains('CHANNEL_PRIVATE') ||
        msg.contains('USER_BANNED_IN_CHANNEL');
  }

  /// Centralized rate limit coordinator spanning all parallel workers
  static void triggerGlobalRateLimit(int seconds) {
    final resumeTime = DateTime.now().add(Duration(seconds: seconds));
    if (_rateLimitUntil == null || resumeTime.isAfter(_rateLimitUntil!)) {
      _rateLimitUntil = resumeTime;
    }
    engineStatusNotifier.value = SyncEngineStatus.rateLimited;
    engineStatusMessageNotifier.value = 'Telegram flood wait active ($seconds s)';
    rateLimitSecondsRemainingNotifier.value = seconds;

    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _rateLimitUntil?.difference(DateTime.now()).inSeconds ?? 0;
      if (remaining <= 0) {
        timer.cancel();
        _rateLimitTimer = null;
        _rateLimitUntil = null;
        rateLimitSecondsRemainingNotifier.value = 0;
        if (instance._isSyncing) {
          engineStatusNotifier.value = SyncEngineStatus.active;
          engineStatusMessageNotifier.value = '';
          uploadSpeedNotifier.value = '';
        }
      } else {
        rateLimitSecondsRemainingNotifier.value = remaining;
        uploadSpeedNotifier.value = 'Cooldown (${remaining}s)';
      }
    });
  }

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

  // ──────────────────────────────────────────────────────────────────────────
  // ENGINE LIFECYCLE & SELF-RESTART
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> startSync() async {
    if (_isSyncing) return;
    if (!Prefs.isConfigured()) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
      engineStatusMessageNotifier.value = 'Telegram not configured.';
      return;
    }

    _isSyncing = true;
    _syncCompleter = Completer<void>();

    // Reset any interrupted uploading state from abrupt app closes
    await DatabaseHelper.instance.resetUploadingToPending();
    await fetchCurrentStats();

    final online = await hasInternetConnection();
    if (!online) {
      engineStatusNotifier.value = SyncEngineStatus.offline;
      engineStatusMessageNotifier.value = 'Offline. Waiting for internet connection...';
    } else {
      engineStatusNotifier.value = SyncEngineStatus.active;
      engineStatusMessageNotifier.value = 'Turbo upload workers active (4x parallel).';
    }

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
    if (engineStatusNotifier.value == SyncEngineStatus.active) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
    }
    fetchCurrentStats();
    _syncCompleter?.complete();
  }

  /// Self-healing full engine restart:
  /// Halts workers, resets socket pool, cleans stuck queue items, tests network, and restarts.
  Future<void> restartEngine() async {
    if (engineStatusNotifier.value == SyncEngineStatus.restarting) return;
    engineStatusNotifier.value = SyncEngineStatus.restarting;
    engineStatusMessageNotifier.value = 'Self-healing: restarting engine & resetting sockets...';

    // 1. Halt workers
    _isSyncing = false;
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _rateLimitUntil = null;
    rateLimitSecondsRemainingNotifier.value = 0;

    // 2. Invalidate and reset MTProto socket pool
    TelegramAuthService.instance.resetClientPool();

    // 3. Reset any stuck UPLOADING items back to PENDING in database
    await DatabaseHelper.instance.resetUploadingToPending();

    // 4. Reset speed meters & metrics
    _totalBytesAccumulator = 0;
    _lastSampleBytes = 0;
    _lastSampleTime = DateTime.now();
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';

    await Future.delayed(const Duration(milliseconds: 500));

    // 5. Check internet connectivity
    final online = await hasInternetConnection();
    if (!online) {
      engineStatusNotifier.value = SyncEngineStatus.offline;
      engineStatusMessageNotifier.value = 'No internet connection. Waiting for network...';
      await fetchCurrentStats();
      return;
    }

    // 6. Check Telegram configuration
    if (!Prefs.isConfigured()) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
      engineStatusMessageNotifier.value = 'Telegram credentials not configured.';
      await fetchCurrentStats();
      return;
    }

    // 7. Restart workers if monitoring enabled
    if (Prefs.monitoringEnabled && !Prefs.uploadPaused) {
      engineStatusNotifier.value = SyncEngineStatus.active;
      engineStatusMessageNotifier.value = 'Engine restarted. Workers active.';
      await startSync();
    } else {
      engineStatusNotifier.value = Prefs.uploadPaused ? SyncEngineStatus.paused : SyncEngineStatus.idle;
      engineStatusMessageNotifier.value = 'Engine restarted successfully.';
      await fetchCurrentStats();
    }
  }

  /// Fast manual check to verify connection and resume queue if online
  Future<bool> checkNetworkAndResume() async {
    final online = await hasInternetConnection();
    if (online) {
      if (engineStatusNotifier.value == SyncEngineStatus.offline) {
        if (_isSyncing) {
          engineStatusNotifier.value = SyncEngineStatus.active;
          engineStatusMessageNotifier.value = 'Connection restored. Resuming backup...';
        } else if (Prefs.monitoringEnabled && !Prefs.uploadPaused) {
          startSync();
        } else {
          engineStatusNotifier.value = SyncEngineStatus.idle;
        }
      }
      return true;
    }
    return false;
  }

  static Future<void> _handleOfflineWait() async {
    engineStatusNotifier.value = SyncEngineStatus.offline;
    engineStatusMessageNotifier.value = 'No internet connection. Waiting for network to resume...';
    uploadSpeedNotifier.value = 'Offline';

    while (instance._isSyncing && !await hasInternetConnection()) {
      await Future.delayed(const Duration(seconds: 3));
    }

    if (instance._isSyncing) {
      engineStatusNotifier.value = SyncEngineStatus.active;
      engineStatusMessageNotifier.value = 'Connection restored. Resuming backup...';
      uploadSpeedNotifier.value = '';
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WORKER POOL & UPLOAD LOGIC
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _runWorkerPool() async {
    engineStatusNotifier.value = SyncEngineStatus.active;
    final workers = List.generate(_workerCount, (index) => _workerLoop(index));
    await Future.wait(workers);

    _isSyncing = false;
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    if (engineStatusNotifier.value == SyncEngineStatus.active) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
    }
    await fetchCurrentStats();
    _syncCompleter?.complete();
  }

  Future<void> _workerLoop(int workerIndex) async {
    while (_isSyncing) {
      // 1. Check global rate limit cooldown
      if (_rateLimitUntil != null && DateTime.now().isBefore(_rateLimitUntil!)) {
        final waitSeconds = _rateLimitUntil!.difference(DateTime.now()).inSeconds;
        await Future.delayed(Duration(seconds: waitSeconds.clamp(1, 60)));
        continue;
      }

      // 2. Check user pause
      if (Prefs.uploadPaused) {
        uploadSpeedNotifier.value = 'Paused';
        engineStatusNotifier.value = SyncEngineStatus.paused;
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      // 3. Check network connectivity
      if (!await hasInternetConnection()) {
        await _handleOfflineWait();
        continue;
      }

      // 4. Atomically claim the next pending item in strict chronological order (dateTaken ASC)
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

      UploadResult result;
      try {
        result = await _uploadWithSpeedOptimization(item, file, workerIndex: workerIndex);
      } catch (e) {
        result = Failure(e.toString());
      }

      if (result is Success) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusDone,
          telegramMessageId: result.telegramMessageId,
          errorReason: null,
          retryCount: 0,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        Prefs.lastSyncedTs = DateTime.now().millisecondsSinceEpoch;
        _accumulateFinishedBytes(await file.length());
        fetchCurrentStats();
      } else if (result is TelegramError) {
        final isAuthExpired = isSessionExpiredError(result.code, result.description);
        final isRateLimit = isRateLimitError(result.code, result.description);
        final isNetwork = isNetworkError(result.description);
        final isPermission = isChannelPermissionError(result.code, result.description);

        if (isAuthExpired) {
          debugPrint('[SyncEngine] Telegram session expired or revoked: ${result.description}');
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          engineStatusNotifier.value = SyncEngineStatus.sessionExpired;
          engineStatusMessageNotifier.value = 'Telegram session expired. Please re-authenticate.';
          TelegramAuthService.instance.resetClientPool();
          stopSync();
          break;
        } else if (isRateLimit) {
          final waitSec = extractFloodWaitSeconds(result.description, result.retryAfterSeconds);
          debugPrint('[SyncEngine] Telegram Rate Limit FLOOD_WAIT: ${waitSec}s');
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          fetchCurrentStats();
          triggerGlobalRateLimit(waitSec);
          await Future.delayed(Duration(seconds: waitSec.clamp(1, 60)));
        } else if (isNetwork) {
          debugPrint('[SyncEngine] Network drop detected in TelegramError: ${result.description}');
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          TelegramAuthService.instance.invalidateClient(workerIndex);
          await _handleOfflineWait();
        } else if (isPermission) {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusFailed,
            errorReason: 'Channel Permission Denied: ${result.description}',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          fetchCurrentStats();
        } else {
          // Transient error: retry up to maxItemRetries with exponential backoff
          TelegramAuthService.instance.invalidateClient(workerIndex);
          if (item.retryCount < maxItemRetries) {
            final nextRetry = item.retryCount + 1;
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusPending,
              retryCount: nextRetry,
              errorReason: 'Retrying ($nextRetry/$maxItemRetries): ${result.description}',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            fetchCurrentStats();
            await Future.delayed(Duration(milliseconds: 500 * (1 << nextRetry)));
          } else {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusFailed,
              errorReason: result.description,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            fetchCurrentStats();
          }
        }
      } else if (result is Failure) {
        final isAuthExpired = isSessionExpiredError(null, result.message);
        final isRateLimit = isRateLimitError(null, result.message);
        final isNetwork = isNetworkError(result.message) || !await hasInternetConnection();

        if (isAuthExpired) {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          engineStatusNotifier.value = SyncEngineStatus.sessionExpired;
          engineStatusMessageNotifier.value = 'Telegram session expired. Please re-authenticate.';
          TelegramAuthService.instance.resetClientPool();
          stopSync();
          break;
        } else if (isRateLimit) {
          final waitSec = extractFloodWaitSeconds(result.message);
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          fetchCurrentStats();
          triggerGlobalRateLimit(waitSec);
          await Future.delayed(Duration(seconds: waitSec.clamp(1, 60)));
        } else if (isNetwork) {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          TelegramAuthService.instance.invalidateClient(workerIndex);
          await _handleOfflineWait();
        } else {
          // Transient failure: retry up to maxItemRetries with backoff
          TelegramAuthService.instance.invalidateClient(workerIndex);
          if (item.retryCount < maxItemRetries) {
            final nextRetry = item.retryCount + 1;
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusPending,
              retryCount: nextRetry,
              errorReason: 'Retrying ($nextRetry/$maxItemRetries): ${result.message}',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            fetchCurrentStats();
            await Future.delayed(Duration(milliseconds: 500 * (1 << nextRetry)));
          } else {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusFailed,
              errorReason: result.message,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            fetchCurrentStats();
          }
        }
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
