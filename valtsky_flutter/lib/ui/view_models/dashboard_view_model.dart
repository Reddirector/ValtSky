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
    }

    // Monitoring controls automatic gallery scanning.
    // Queued items continue uploading regardless of monitoring state unless explicitly paused.
    if (!Prefs.uploadPaused) {
      SyncEngine().startSync();
    }
    notifyListeners();
  }

  void togglePauseUpload() {
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
    try {
      SyncEngine.instance.stopSync();
      await DatabaseHelper.instance.resetUploadingToPending();
      SyncEngine.uploadSpeedNotifier.value = 'Stopped';
      SyncEngine.currentItemNotifier.value = '';
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
      SyncEngine.engineStatusMessageNotifier.value = 'Process stopped by user.';
      await refreshStats();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.stop_circle_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Process stopped: active workers halted.')),
              ],
            ),
            duration: const Duration(seconds: 2),
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
