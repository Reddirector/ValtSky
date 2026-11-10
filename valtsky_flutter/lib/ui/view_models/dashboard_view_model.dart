import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/models/media_item.dart';
import '../../data/prefs.dart';
import '../../services/background_service.dart';
import '../../services/sync_engine.dart';
import '../../util/media_scanner.dart';
import '../../util/theme.dart';

class DashboardViewModel extends ChangeNotifier {
  int totalCount = 0;
  int uploadedCount = 0;
  int pendingCount = 0;
  int failedCount = 0;
  int uploadingCount = 0;
  double progress = 0.0;

  bool isRefreshing = false;
  List<MediaItem> cachedFailedItems = [];
  List<MediaItem> recentItems = [];

  DashboardViewModel() {
    _init();
  }

  void _init() {
    SyncEngine.statsNotifier.addListener(_onStatsChanged);
    SyncEngine.engineStatusNotifier.addListener(notifyListeners);
    SyncEngine.rateLimitSecondsRemainingNotifier.addListener(notifyListeners);
    refreshStats();
  }

  @override
  void dispose() {
    SyncEngine.statsNotifier.removeListener(_onStatsChanged);
    SyncEngine.engineStatusNotifier.removeListener(notifyListeners);
    SyncEngine.rateLimitSecondsRemainingNotifier.removeListener(notifyListeners);
    super.dispose();
  }

  void _onStatsChanged() {
    final stats = SyncEngine.statsNotifier.value;
    if (stats != null) {
      final prevFailed = failedCount;
      totalCount = stats.total;
      uploadedCount = stats.synced;
      pendingCount = stats.inQueue;
      failedCount = stats.failed;
      uploadingCount = stats.uploading;
      progress = stats.progress;

      if ((prevFailed > 0) != (failedCount > 0)) {
        if (failedCount > 0) {
          loadFailedItems();
        } else {
          cachedFailedItems = [];
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> loadFailedItems() async {
    final items = await DatabaseHelper.instance.getFailedItems(limit: 2);
    cachedFailedItems = items;
    notifyListeners();
  }

  Future<void> refreshStats() async {
    final stats = await SyncEngine.fetchCurrentStats(forceDb: true);
    totalCount = stats.total;
    uploadedCount = stats.synced;
    pendingCount = stats.inQueue;
    failedCount = stats.failed;
    uploadingCount = stats.uploading;
    progress = stats.progress;

    if (failedCount > 0) {
      cachedFailedItems = await DatabaseHelper.instance.getFailedItems(limit: 2);
    } else {
      cachedFailedItems = [];
    }
    recentItems = await DatabaseHelper.instance.getAllItems(limit: 4);
    notifyListeners();
  }

  Future<void> toggleMonitoring(BuildContext context, {required VoidCallback onNavigateToSettings}) async {
    if (!Prefs.isConfigured()) {
      _showNotConfiguredDialog(context, onNavigateToSettings: onNavigateToSettings);
      return;
    }

    final newStatus = !Prefs.monitoringEnabled;
    Prefs.monitoringEnabled = newStatus;

    if (newStatus) {
      // Starting monitoring begins a fresh session and empties the tank to 0%
      SyncEngine.startNewSession();
    }

    if (!kIsWeb) {
      if (newStatus) {
        await BackgroundService.start();
        // Fast incremental scan for media taken while monitoring was off
        MediaScanner.scanForNewMedia(forceFull: false).then((_) {
          refreshStats();
        });
      } else {
        await BackgroundService.stop();
      }
    } else {
      if (newStatus) {
        MediaScanner.scanForNewMedia(forceFull: false).then((_) {
          refreshStats();
        });
      }
    }

    // Monitoring controls automatic gallery scanning.
    // Queued items continue uploading regardless of monitoring state unless explicitly paused.
    if (!Prefs.uploadPaused) {
      SyncEngine().startSync();
    }
    notifyListeners();
  }

  void togglePauseUpload() {
    if (!SyncEngine.instance.isSyncing) {
      Prefs.uploadPaused = false;
      SyncEngine.uploadSpeedNotifier.value = '';
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.active;
      SyncEngine().startSync();
      notifyListeners();
      return;
    }
    final newPaused = !Prefs.uploadPaused;
    Prefs.uploadPaused = newPaused;
    if (newPaused) {
      SyncEngine.uploadSpeedNotifier.value = 'Paused';
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.paused;
    } else {
      SyncEngine.uploadSpeedNotifier.value = '';
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.active;
      SyncEngine().startSync();
    }
    notifyListeners();
  }

  Future<void> handleStopProcess(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ─── STEP 1: INITIAL WARNING CONFIRMATION ──────────────────────────────
    final step1Confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ValtSkyTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stop_circle_rounded, color: ValtSkyTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Kill Process & Empty Queue?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'This will terminate all active upload operations, kill background workers, completely empty the upload queue, and drain the sync tank back to 0%.\n\nBackground monitoring will also be halted.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Running', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed to Step 2', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (step1Confirmed != true) return;
    if (!context.mounted) return;

    // ─── STEP 2: FINAL DOUBLE VERIFICATION CONFIRMATION ────────────────────
    final step2Confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ValtSkyTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: ValtSkyTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Step 2 of 2: Confirm Kill & Clear',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ValtSkyTheme.error),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you absolutely sure you want to stop everything?\n\nWhatever was loading will be halted immediately, the tank will empty itself, and all pending items in the queue will be permanently cleared.\n\nThis action CANNOT be undone.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abort / Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm: Kill & Drain Tank', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (step2Confirmed != true) return;
    if (!context.mounted) return;

    await confirmKillAndClearQueue(context);
  }

  Future<void> confirmKillAndClearQueue(BuildContext context) async {
    try {
      // 1. Kill active sync engine workers
      SyncEngine.instance.stopSync();

      // 2. Halt background monitoring service
      if (!kIsWeb) {
        await BackgroundService.stop();
      }
      Prefs.monitoringEnabled = false;
      Prefs.uploadPaused = false;

      // 3. Completely empty the active upload queue from database
      final cleared = await DatabaseHelper.instance.clearQueueItems();

      // 4. Empty the tank completely and reset the sync session
      SyncEngine.resetSession();
      progress = 0.0;

      // 5. Update engine status notifiers
      SyncEngine.uploadSpeedNotifier.value = 'Stopped';
      SyncEngine.currentItemNotifier.value = '';
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
      SyncEngine.engineStatusMessageNotifier.value =
          'Process terminated. Queue cleared and tank drained.';

      await refreshStats();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Process killed: $cleared items cleared, tank drained to 0%.'),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Stop error: $e'),
          ),
        );
      }
    }
    notifyListeners();
  }

  void _showNotConfiguredDialog(BuildContext context, {required VoidCallback onNavigateToSettings}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ValtSkyTheme.telegramBlue.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_rounded, color: ValtSkyTheme.telegramBlue, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Connect Telegram', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Connect your Telegram account in Settings to activate automated background cloud sync.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Later', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.telegramBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onNavigateToSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
