import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:photo_manager/photo_manager.dart';
import '../data/db/database_helper.dart';
import '../data/prefs.dart';
import 'sync_engine.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  String _lastNotificationText = '';
  bool _isBackgroundSyncActive = false;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await Prefs.init();
    PhotoManager.setIgnorePermissionCheck(true);
    await DatabaseHelper.instance.database;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Ping main isolate so if it is alive, it knows the background worker is healthy.
    sendPort?.send('keep_alive');

    try {
      await Prefs.init();
      await Prefs.reload();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastMain = Prefs.lastMainHeartbeat;
      final isMainAlive = (now - lastMain) < 30000;

      if (isMainAlive) {
        // Main UI is alive and managing sync. If background sync was active, yield to main.
        if (_isBackgroundSyncActive) {
          SyncEngine.instance.stopSync();
          _isBackgroundSyncActive = false;
          Prefs.isBackgroundSyncActive = false;
        }
        // Main isolate actively updates notification with real-time stats; do not clobber it.
        return;
      }

      // If the user swiped the app away or the main UI died, the background service
      // autonomously continues uploading any pending media until complete.
      if (Prefs.isConfigured() && !Prefs.uploadPaused) {
        if (!_isBackgroundSyncActive && !SyncEngine.instance.isSyncing) {
          final pending = await DatabaseHelper.instance.getPendingCount();
          if (pending > 0) {
            _isBackgroundSyncActive = true;
            Prefs.isBackgroundSyncActive = true;
            SyncEngine.isBackgroundEngine = true;
            debugPrint('[BackgroundService] UI inactive/closed. Autonomous sync starting for $pending items.');
            unawaited(SyncEngine.instance.startSync().whenComplete(() {
              _isBackgroundSyncActive = false;
              Prefs.isBackgroundSyncActive = false;
            }));
          }
        }
      }

      final isUploading = _isBackgroundSyncActive || SyncEngine.instance.isSyncing;
      final statusText = isUploading
          ? 'Syncing media to your vault...'
          : Prefs.uploadPaused
              ? 'Upload paused'
              : 'Monitoring for new photos...';

      if (statusText != _lastNotificationText) {
        _lastNotificationText = statusText;
        FlutterForegroundTask.updateService(
          notificationTitle: 'ValtSky Active',
          notificationText: statusText,
        );
      }
    } catch (e) {
      debugPrint('[BackgroundService] Notification/sync update error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _isBackgroundSyncActive = false;
    Prefs.isBackgroundSyncActive = false;
  }
}

class BackgroundService {
  static ReceivePort? _receivePort;

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'valtsky_monitor',
        channelName: 'ValtSky Monitoring',
        channelDescription: 'Keeps ValtSky monitoring and uploading media',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 15000, // 15s keep-alive interval: checks queue quickly when app is backgrounded/swiped
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> isRunning() => FlutterForegroundTask.isRunningService;

  static Future<bool> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      if (_receivePort == null) {
        _receivePort = FlutterForegroundTask.receivePort;
        _receivePort?.listen(_onReceiveData);
      }
      return true;
    }

    // Set up receive port to listen for keep-alive pings from the task handler
    _receivePort?.close();
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen(_onReceiveData);

    return FlutterForegroundTask.startService(
      notificationTitle: 'ValtSky Active',
      notificationText: 'Syncing media to your vault...',
      callback: startCallback,
    );
  }

  /// Updates the foreground notification text/title during active transfer
  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (_) {}
  }

  /// Ensures Android battery optimization is ignored so Doze mode does not sleep network/CPU
  static Future<void> checkAndRequestBatteryOptimization() async {
    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('[BackgroundService] Battery optimization request: $e');
    }
  }

  /// Handles keep-alive pings from the background task handler.
  /// This ensures the main isolate stays warm and the sync engine keeps working.
  static void _onReceiveData(dynamic data) {
    if (data == 'keep_alive') {
      debugPrint('[BackgroundService] Keep-alive received, engine stays warm.');
    }
  }

  static Future<bool> stop() async {
    _receivePort?.close();
    _receivePort = null;
    try {
      return await FlutterForegroundTask.stopService().timeout(const Duration(milliseconds: 300));
    } catch (_) {
      return false;
    }
  }
}
