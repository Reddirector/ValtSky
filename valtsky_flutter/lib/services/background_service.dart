import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:photo_manager/photo_manager.dart';
import '../data/prefs.dart';
import '../util/media_scanner.dart';
import 'sync_engine.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  final SyncEngine _syncEngine = SyncEngine();
  DateTime? _lastScan;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    await Prefs.init();
    PhotoManager.setIgnorePermissionCheck(true);
    _syncEngine.startSync();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Check for new media every minute
    if (_lastScan == null || timestamp.difference(_lastScan!) > const Duration(minutes: 1)) {
      PhotoManager.setIgnorePermissionCheck(true);
      await MediaScanner.scanForNewMedia();
      _lastScan = timestamp;
      _syncEngine.startSync(); // Ensure sync engine is running
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _syncEngine.stopSync();
  }
}

class BackgroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'valtsky_monitor',
        channelName: 'ValtSky Monitoring',
        channelDescription: 'Keeps ValtSky monitoring for new photos',
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
        interval: 60000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> start() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'ValtSky Monitoring',
        notificationText: 'Scanning for new photos...',
        callback: startCallback,
      );
    }
  }

  static Future<bool> stop() async {
    try {
      return await FlutterForegroundTask.stopService().timeout(const Duration(milliseconds: 300));
    } catch (_) {
      return false;
    }
  }
}
