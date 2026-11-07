import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../data/db/database_helper.dart';
import '../data/models/media_item.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';
import 'telegram_auth_service.dart';
import 'background_service.dart';
import '../util/file_security_guard.dart';
import '../util/media_scanner.dart';

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

  SyncStats copyWith({
    int? total,
    int? synced,
    int? inQueue,
    int? failed,
    int? uploading,
    double? progress,
  }) {
    final t = total ?? this.total;
    final s = synced ?? this.synced;
    final p = progress ?? (t == 0 ? 0.0 : (s / t).clamp(0.0, 1.0));
    return SyncStats(
      total: t,
      synced: s,
      inQueue: inQueue ?? this.inQueue,
      failed: failed ?? this.failed,
      uploading: uploading ?? this.uploading,
      progress: p,
    );
  }
}

class SyncEngine {
  static final SyncEngine instance = SyncEngine._internal();
  SyncEngine._internal();
  factory SyncEngine() => instance;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  Completer<void>? _syncCompleter;

  // 2 high-throughput parallel upload workers for maximum wire speed with 0 UI lag
  static const int _workerCount = 2;
  static int get workerCount => _workerCount;
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

  static SyncStats _cachedStats = const SyncStats(
    total: 0,
    synced: 0,
    inQueue: 0,
    failed: 0,
    uploading: 0,
    progress: 0.0,
  );

  static int _totalBytesSent = 0;
  static int _prevBytesSent = 0;
  static DateTime _lastSpeedSampleTime = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastActiveTransferTime = DateTime.fromMillisecondsSinceEpoch(0);
  static double _smoothedSpeedMBps = 0.0;
  static Timer? _speedMeterTimer;

  static DateTime _lastStatsNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _statsNotifyScheduled = false;

  static void _scheduleStatsNotification() {
    final now = DateTime.now();
    if (now.difference(_lastStatsNotify).inMilliseconds >= 500) {
      _lastStatsNotify = now;
      statsNotifier.value = _cachedStats;
    } else if (!_statsNotifyScheduled) {
      _statsNotifyScheduled = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        _statsNotifyScheduled = false;
        _lastStatsNotify = DateTime.now();
        statsNotifier.value = _cachedStats;
      });
    }
  }

  static DateTime _lastItemNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static void _updateCurrentItemThrottled(String fileName) {
    final now = DateTime.now();
    if (now.difference(_lastItemNotify).inMilliseconds >= 500) {
      _lastItemNotify = now;
      currentItemNotifier.value = fileName;
    }
  }

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
        msg.contains('CHANNEL_INVALID') ||
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

  // ──────────────────────────────────────────────────────────────────────────
  // IN-MEMORY REAL-TIME ATOMIC COUNTERS (0ms UI Latency, 0 Disk I/O during sync)
  // ──────────────────────────────────────────────────────────────────────────

  static void _updateInFlightClaim() {
    _cachedStats = _cachedStats.copyWith(
      inQueue: (_cachedStats.inQueue - 1).clamp(0, 9999999),
      uploading: _cachedStats.uploading + 1,
    );
    _scheduleStatsNotification();
  }

  static void _updateInFlightSuccess() {
    _cachedStats = _cachedStats.copyWith(
      uploading: (_cachedStats.uploading - 1).clamp(0, 9999999),
      synced: _cachedStats.synced + 1,
    );
    _scheduleStatsNotification();
  }

  static void _updateInFlightFailure() {
    _cachedStats = _cachedStats.copyWith(
      uploading: (_cachedStats.uploading - 1).clamp(0, 9999999),
      failed: _cachedStats.failed + 1,
    );
    _scheduleStatsNotification();
  }

  static void _updateInFlightRetry() {
    _cachedStats = _cachedStats.copyWith(
      uploading: (_cachedStats.uploading - 1).clamp(0, 9999999),
      inQueue: _cachedStats.inQueue + 1,
    );
    _scheduleStatsNotification();
  }

  /// Query SQLite and notify all UI listeners with fresh baseline counts in 1 fast query
  static Future<SyncStats> fetchCurrentStats({bool forceDb = true}) async {
    final counts = await DatabaseHelper.instance.getAggregatedCounts();
    final total = counts['total'] ?? 0;
    final synced = counts['synced'] ?? 0;
    final inQueue = counts['inQueue'] ?? 0;
    final failed = counts['failed'] ?? 0;
    final uploading = counts['uploading'] ?? 0;
    final progress = total == 0 ? 0.0 : (synced / total).clamp(0.0, 1.0);
    _cachedStats = SyncStats(
      total: total,
      synced: synced,
      inQueue: inQueue,
      failed: failed,
      uploading: uploading,
      progress: progress,
    );
    statsNotifier.value = _cachedStats;
    return _cachedStats;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LOGOUT RESET & NEW VAULT RE-INITIALIZATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Completely resets all sync state, stops workers, wipes SQLite database, and zeroes counters on logout
  Future<void> fullLogoutAndReset() async {
    stopSync();
    if (!kIsWeb) {
      try {
        await BackgroundService.stop();
      } catch (_) {}
    }
    try {
      TelegramAuthService.instance.resetClientPool();
      TelegramAuthService.instance.reset();
    } catch (_) {}

    // Wipe all media items from the database so old synced states are purged
    try {
      await DatabaseHelper.instance.deleteAll();
    } catch (_) {}

    // Zero out in-memory stats
    _cachedStats = const SyncStats(
      total: 0,
      synced: 0,
      inQueue: 0,
      failed: 0,
      uploading: 0,
      progress: 0.0,
    );
    statsNotifier.value = _cachedStats;

    // Reset notifiers
    _claimedBatchQueue.clear();
    _speedMeterTimer?.cancel();
    _speedMeterTimer = null;
    _totalBytesSent = 0;
    _prevBytesSent = 0;
    engineStatusNotifier.value = SyncEngineStatus.idle;
    engineStatusMessageNotifier.value = '';
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    rateLimitSecondsRemainingNotifier.value = 0;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _rateLimitUntil = null;

    // Disconnect credentials and preferences
    await Prefs.disconnectTelegram();
  }

  /// Prepares a fresh vault session for a newly connected Telegram channel/account
  Future<void> initializeNewVaultSession() async {
    // 1. Reset counters to baseline
    _cachedStats = const SyncStats(
      total: 0,
      synced: 0,
      inQueue: 0,
      failed: 0,
      uploading: 0,
      progress: 0.0,
    );
    statsNotifier.value = _cachedStats;

    // 2. Monitoring stays OFF by default until the user explicitly commands it
    Prefs.monitoringEnabled = false;
    Prefs.uploadPaused = false;
    engineStatusNotifier.value = SyncEngineStatus.idle;
    engineStatusMessageNotifier.value = 'Telegram linked. Ready to start backup when commanded.';

    // 3. Scan camera roll cleanly into fresh database
    await MediaScanner.scanForNewMedia();

    // 4. Populate live stats from database
    await fetchCurrentStats(forceDb: true);
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

    // Reset any interrupted uploading state from abrupt app closes and retry failed items
    await DatabaseHelper.instance.resetUploadingToPending();
    await DatabaseHelper.instance.retryAllFailed();
    await fetchCurrentStats(forceDb: true);

    final online = await hasInternetConnection();
    if (!online) {
      engineStatusNotifier.value = SyncEngineStatus.offline;
      engineStatusMessageNotifier.value = 'Offline. Waiting for internet connection...';
    } else {
      engineStatusNotifier.value = SyncEngineStatus.active;
      engineStatusMessageNotifier.value = 'Turbo upload workers active (2x parallel).';
    }

    _totalBytesSent = 0;
    _prevBytesSent = 0;
    _smoothedSpeedMBps = 0.0;
    _lastSpeedSampleTime = DateTime.now();
    _lastActiveTransferTime = DateTime.now();
    _speedMeterTimer?.cancel();

    // Smooth, low-overhead speed sampler (300ms window = ~3 updates/sec, <0.01% CPU)
    _speedMeterTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_isSyncing) return;
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastSpeedSampleTime).inMilliseconds;
      if (elapsedMs < 100) return;

      final current = _totalBytesSent;
      final deltaBytes = current - _prevBytesSent;
      _prevBytesSent = current;
      _lastSpeedSampleTime = now;

      if (deltaBytes > 0) {
        _lastActiveTransferTime = now;
        final instantMBps = (deltaBytes / (1024 * 1024)) / (elapsedMs / 1000.0);
        if (_smoothedSpeedMBps <= 0.01) {
          _smoothedSpeedMBps = instantMBps;
        } else {
          // Exponential moving average: 0.6 instant + 0.4 historical for responsive yet stable tracking
          _smoothedSpeedMBps = (_smoothedSpeedMBps * 0.4) + (instantMBps * 0.6);
        }
      } else {
        // Inter-file transition or idle period: hold active transfer rate for up to 2 seconds
        final idleMs = now.difference(_lastActiveTransferTime).inMilliseconds;
        if (idleMs > 2000) {
          _smoothedSpeedMBps = _smoothedSpeedMBps * 0.6;
          if (_smoothedSpeedMBps < 0.05) _smoothedSpeedMBps = 0.0;
        }
      }

      if (_rateLimitUntil == null && !Prefs.uploadPaused) {
        String newSpeedText;
        if (_smoothedSpeedMBps >= 1.0) {
          newSpeedText = '${_smoothedSpeedMBps.toStringAsFixed(1)} MB/s';
        } else if (_smoothedSpeedMBps >= 0.001) {
          final kbps = (_smoothedSpeedMBps * 1024).round();
          newSpeedText = '$kbps KB/s';
        } else {
          newSpeedText = 'Syncing...';
        }

        if (uploadSpeedNotifier.value != newSpeedText) {
          uploadSpeedNotifier.value = newSpeedText;
        }
      }
    });

    // Light periodic consistency check every 10 seconds (in WAL mode, 1 fast query)
    _liveStatsTimer?.cancel();
    _liveStatsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isSyncing) {
        fetchCurrentStats(forceDb: true);
      }
    });

    _runWorkerPool();
  }

  void stopSync() {
    _isSyncing = false;
    _claimedBatchQueue.clear();
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    _speedMeterTimer?.cancel();
    _speedMeterTimer = null;
    _totalBytesSent = 0;
    _prevBytesSent = 0;
    _smoothedSpeedMBps = 0.0;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';
    if (engineStatusNotifier.value == SyncEngineStatus.active) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
    }
    fetchCurrentStats(forceDb: true);
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter!.complete();
    }
    _syncCompleter = null;
  }

  /// Self-healing full engine restart:
  /// Halts workers, resets socket pool, cleans stuck queue items, tests network, and restarts.
  Future<void> restartEngine() async {
    if (engineStatusNotifier.value == SyncEngineStatus.restarting) return;
    engineStatusNotifier.value = SyncEngineStatus.restarting;
    engineStatusMessageNotifier.value = 'Self-healing: restarting engine & resetting sockets...';

    // 1. Halt workers and await active loop shutdown
    _isSyncing = false;
    _claimedBatchQueue.clear();
    if (_workerPoolFuture != null) {
      try {
        await _workerPoolFuture!.timeout(const Duration(seconds: 3));
      } catch (_) {}
      _workerPoolFuture = null;
    }
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter!.complete();
    }
    _syncCompleter = null;
    _liveStatsTimer?.cancel();
    _liveStatsTimer = null;
    _speedMeterTimer?.cancel();
    _speedMeterTimer = null;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _rateLimitUntil = null;
    rateLimitSecondsRemainingNotifier.value = 0;

    // 2. Invalidate and reset MTProto socket pool
    TelegramAuthService.instance.resetClientPool();

    // 3. Reset any stuck UPLOADING items back to PENDING and failed items in database
    await DatabaseHelper.instance.resetUploadingToPending();
    await DatabaseHelper.instance.retryAllFailed();

    // 4. Reset speed meters & metrics
    _totalBytesSent = 0;
    _prevBytesSent = 0;
    uploadSpeedNotifier.value = '';
    currentItemNotifier.value = '';

    await Future.delayed(const Duration(milliseconds: 500));

    // 5. Check internet connectivity
    final online = await hasInternetConnection();
    if (!online) {
      engineStatusNotifier.value = SyncEngineStatus.offline;
      engineStatusMessageNotifier.value = 'No internet connection. Waiting for network...';
      await fetchCurrentStats(forceDb: true);
      return;
    }

    // 6. Check Telegram configuration
    if (!Prefs.isConfigured()) {
      engineStatusNotifier.value = SyncEngineStatus.idle;
      engineStatusMessageNotifier.value = 'Telegram credentials not configured.';
      await fetchCurrentStats(forceDb: true);
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
      await fetchCurrentStats(forceDb: true);
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

  Future<void>? _workerPoolFuture;

  Future<void> _runWorkerPool() async {
    engineStatusNotifier.value = SyncEngineStatus.active;
    try {
      final workers = List.generate(_workerCount, (index) => _workerLoop(index));
      _workerPoolFuture = Future.wait(workers);
      await _workerPoolFuture;
    } catch (e) {
      debugPrint('[SyncEngine] Worker pool caught exception: $e');
    } finally {
      _workerPoolFuture = null;
      _isSyncing = false;
      _liveStatsTimer?.cancel();
      _liveStatsTimer = null;
      _speedMeterTimer?.cancel();
      _speedMeterTimer = null;
      _smoothedSpeedMBps = 0.0;
      uploadSpeedNotifier.value = '';
      currentItemNotifier.value = '';
      if (engineStatusNotifier.value == SyncEngineStatus.active) {
        engineStatusNotifier.value = SyncEngineStatus.idle;
      }
      await fetchCurrentStats(forceDb: true);
      if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
      _syncCompleter = null;
    }
  }

  static final List<MediaItem> _claimedBatchQueue = [];
  static Completer<void>? _batchRefillCompleter;

  Future<MediaItem?> _getNextPendingItem() async {
    while (_isSyncing) {
      if (_claimedBatchQueue.isNotEmpty) {
        return _claimedBatchQueue.removeAt(0);
      }
      if (_batchRefillCompleter != null) {
        await _batchRefillCompleter!.future;
        if (_claimedBatchQueue.isNotEmpty) {
          return _claimedBatchQueue.removeAt(0);
        }
        continue;
      }
      _batchRefillCompleter = Completer<void>();
      try {
        final batch = await DatabaseHelper.instance.claimPendingBatch(limit: 32);
        if (batch.isEmpty) {
          return null; // Database has no more pending items!
        }
        _claimedBatchQueue.addAll(batch);
        return _claimedBatchQueue.removeAt(0);
      } finally {
        _batchRefillCompleter?.complete();
        _batchRefillCompleter = null;
      }
    }
    return null;
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

      // 4. Atomically claim next item from RAM buffer (0ms, zero SQLite lock contention)
      final item = await _getNextPendingItem();
      if (item == null) {
        // Queue is drained
        break;
      }

      final fileName = item.filePath.split('/').last;
      _updateCurrentItemThrottled(fileName);
      _updateInFlightClaim();

      // Non-blocking microtask yield for smooth 120 FPS UI rendering without artificial latency
      await Future.delayed(Duration.zero);

      final file = File(item.filePath);
      if (!await file.exists()) {
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusFailed,
          errorReason: 'File not found on storage',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        _updateInFlightFailure();
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
        _updateInFlightFailure();
        continue;
      }

      int workerItemBytesSent = 0;
      void handleProgress(int sent, int total) {
        final delta = sent - workerItemBytesSent;
        if (delta > 0) {
          _totalBytesSent += delta;
          workerItemBytesSent = sent;
        }
      }

      UploadResult result;
      try {
        result = await _uploadWithSpeedOptimization(
          item,
          file,
          workerIndex: workerIndex,
          onProgress: handleProgress,
        );
      } catch (e) {
        result = Failure(e.toString());
      }

      if (result is Success) {
        final fileLen = await file.length();
        if (workerItemBytesSent < fileLen) {
          _totalBytesSent += (fileLen - workerItemBytesSent);
          workerItemBytesSent = fileLen;
        }
        await DatabaseHelper.instance.update(item.copyWith(
          status: MediaItem.statusDone,
          telegramMessageId: result.telegramMessageId,
          errorReason: null,
          retryCount: 0,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ));
        Prefs.lastSyncedTs = DateTime.now().millisecondsSinceEpoch;
        _updateInFlightSuccess();
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
          _updateInFlightRetry();
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
          _updateInFlightRetry();
          triggerGlobalRateLimit(waitSec);
          await Future.delayed(Duration(seconds: waitSec.clamp(1, 60)));
        } else if (isNetwork) {
          debugPrint('[SyncEngine] Network drop detected in TelegramError: ${result.description}');
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          _updateInFlightRetry();
          TelegramAuthService.instance.invalidateClient(workerIndex);
          await _handleOfflineWait();
        } else if (isPermission) {
          // If error is CHANNEL_PRIVATE or CHAT_ADMIN_REQUIRED, allow retries if retryCount < maxItemRetries
          // rather than immediately marking permanently failed, as channel access hash may need refreshing.
          if ((result.description.contains('CHANNEL_PRIVATE') ||
               result.description.contains('CHANNEL_INVALID') ||
               result.description.contains('CHAT_ADMIN_REQUIRED')) &&
              item.retryCount < maxItemRetries) {
            final nextRetry = item.retryCount + 1;
            Prefs.channelAccessHash = null;
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusPending,
              retryCount: nextRetry,
              errorReason: 'Refreshing channel access: ${result.description}',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            _updateInFlightRetry();
            await Future.delayed(Duration(milliseconds: 1000 * nextRetry));
          } else {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusFailed,
              errorReason: 'Channel Permission Denied: ${result.description}',
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            _updateInFlightFailure();
          }
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
            _updateInFlightRetry();
            await Future.delayed(Duration(milliseconds: 500 * (1 << nextRetry)));
          } else {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusFailed,
              errorReason: result.description,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            _updateInFlightFailure();
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
          _updateInFlightRetry();
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
          _updateInFlightRetry();
          triggerGlobalRateLimit(waitSec);
          await Future.delayed(Duration(seconds: waitSec.clamp(1, 60)));
        } else if (isNetwork) {
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          _updateInFlightRetry();
          TelegramAuthService.instance.invalidateClient(workerIndex);
          await _handleOfflineWait();
        } else if ((result.message.contains('CHANNEL_PRIVATE') ||
                    result.message.contains('CHANNEL_INVALID') ||
                    result.message.contains('CHAT_ADMIN_REQUIRED')) &&
                   item.retryCount < maxItemRetries) {
          final nextRetry = item.retryCount + 1;
          Prefs.channelAccessHash = null;
          await DatabaseHelper.instance.update(item.copyWith(
            status: MediaItem.statusPending,
            retryCount: nextRetry,
            errorReason: 'Refreshing channel access: ${result.message}',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ));
          _updateInFlightRetry();
          await Future.delayed(Duration(milliseconds: 1000 * nextRetry));
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
            _updateInFlightRetry();
            await Future.delayed(Duration(milliseconds: 500 * (1 << nextRetry)));
          } else {
            await DatabaseHelper.instance.update(item.copyWith(
              status: MediaItem.statusFailed,
              errorReason: result.message,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ));
            _updateInFlightFailure();
          }
        }
      }
    }
  }

  /// High-speed upload with live speed meter and in-memory chunk streaming
  Future<UploadResult> _uploadWithSpeedOptimization(
    MediaItem item,
    File file, {
    int workerIndex = 0,
    void Function(int sent, int total)? onProgress,
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
          onProgress: onProgress,
        );
      } else {
        return await TelegramAuthService.instance.uploadMedia(
          file: file,
          channelId: Prefs.channelId,
          asDocument: Prefs.useOriginalQuality,
          caption: caption,
          onProgress: onProgress,
          workerIndex: workerIndex,
        );
      }
    }

    // Large file: Stream raw chunks in-memory for maximum speed
    return await _streamChunkedFile(
      file,
      fileName,
      fileSize,
      maxSingleBytes,
      dateStr,
      item.fileHash,
      onProgress ?? (sent, total) {},
    );
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
          await Future.delayed(Duration.zero);
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
