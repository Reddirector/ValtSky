import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/prefs.dart';
import '../util/media_scanner.dart';
import 'sync_engine.dart';

/// State of the automated alarm clock backup scheduler
class ScheduledBackupState {
  final bool isEnabled;
  final int hour;
  final int minute;
  final bool repeatDaily;
  final bool isExecuting;
  final String statusMessage;
  final DateTime? nextTriggerTime;
  final DateTime? lastRunTime;
  final int lastRunQueuedCount;

  const ScheduledBackupState({
    this.isEnabled = false,
    this.hour = 2,
    this.minute = 0,
    this.repeatDaily = true,
    this.isExecuting = false,
    this.statusMessage = 'Alarm standby',
    this.nextTriggerTime,
    this.lastRunTime,
    this.lastRunQueuedCount = 0,
  });

  ScheduledBackupState copyWith({
    bool? isEnabled,
    int? hour,
    int? minute,
    bool? repeatDaily,
    bool? isExecuting,
    String? statusMessage,
    DateTime? nextTriggerTime,
    bool clearNextTriggerTime = false,
    DateTime? lastRunTime,
    int? lastRunQueuedCount,
  }) {
    return ScheduledBackupState(
      isEnabled: isEnabled ?? this.isEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      isExecuting: isExecuting ?? this.isExecuting,
      statusMessage: statusMessage ?? this.statusMessage,
      nextTriggerTime: clearNextTriggerTime
          ? null
          : (nextTriggerTime ?? this.nextTriggerTime),
      lastRunTime: lastRunTime ?? this.lastRunTime,
      lastRunQueuedCount: lastRunQueuedCount ?? this.lastRunQueuedCount,
    );
  }

  /// Formatted time string (e.g., "02:00 AM", "11:30 PM")
  String get formattedTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    final formattedHour = displayHour.toString().padLeft(2, '0');
    return '$formattedHour:$displayMinute $period';
  }

  /// Countdown string to next scheduled run (e.g. "in 4h 12m", "in 18m")
  String get countdownText {
    if (isExecuting) {
      return 'Running now';
    }
    if (!isEnabled || nextTriggerTime == null) {
      return 'Alarm off';
    }
    final now = DateTime.now();
    final diff = nextTriggerTime!.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) {
      return 'Starting now...';
    }
    if (diff.inHours > 0) {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return 'in ${hours}h ${minutes}m';
    }
    if (diff.inMinutes > 0) {
      return 'in ${diff.inMinutes}m';
    }
    return 'in ${diff.inSeconds}s';
  }
}

/// Alarm Clock Scheduled Backup Service:
/// Allows the user to set a specific time of day for automatic gallery monitoring
/// and backup. When the scheduled time arrives:
/// 1. Wakes up in background and performs an exhaustive scan of device media.
/// 2. Automatically loads all new/un-synced photos and videos into the queue.
/// 3. Once discovery is complete and the queue holds all items, stops monitoring
///    and automatically initiates Telegram upload.
/// 4. Re-arms itself for the next scheduled occurrence (repeating daily).
class BackupSchedulerService {
  static final BackupSchedulerService instance = BackupSchedulerService._internal();

  BackupSchedulerService._internal();

  final ValueNotifier<ScheduledBackupState> stateNotifier =
      ValueNotifier<ScheduledBackupState>(const ScheduledBackupState());

  Timer? _alarmTimer;
  Timer? _countdownTicker;

  ScheduledBackupState get state => stateNotifier.value;

  /// Test hook to simulate immediate execution without waiting
  @visibleForTesting
  Future<void> Function()? onExecuteWorkflowHook;

  /// Initializes the scheduler from stored preferences.
  Future<void> init() async {
    final enabled = Prefs.scheduledBackupEnabled;
    final hour = Prefs.scheduledBackupHour;
    final minute = Prefs.scheduledBackupMinute;
    final repeat = Prefs.scheduledBackupRepeatDaily;

    DateTime? nextTrigger;
    if (enabled) {
      nextTrigger = calculateNextTrigger(hour: hour, minute: minute);
    }

    stateNotifier.value = ScheduledBackupState(
      isEnabled: enabled,
      hour: hour,
      minute: minute,
      repeatDaily: repeat,
      nextTriggerTime: nextTrigger,
      statusMessage: enabled ? 'Alarm active' : 'Alarm standby',
    );

    if (enabled) {
      _armTimer();
      _startCountdownTicker();
    }
  }

  /// Calculates the next occurrence of [hour]:[minute].
  /// If the time has already passed today, targets tomorrow.
  DateTime calculateNextTrigger({DateTime? fromTime, int? hour, int? minute}) {
    final now = fromTime ?? DateTime.now();
    final targetHour = hour ?? state.hour;
    final targetMinute = minute ?? state.minute;

    var trigger = DateTime(
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );

    if (!trigger.isAfter(now)) {
      trigger = trigger.add(const Duration(days: 1));
    }
    return trigger;
  }

  /// Toggles the automated alarm schedule ON or OFF.
  Future<void> setEnabled(bool enabled) async {
    Prefs.scheduledBackupEnabled = enabled;

    DateTime? nextTrigger;
    if (enabled) {
      nextTrigger = calculateNextTrigger();
    }

    stateNotifier.value = state.copyWith(
      isEnabled: enabled,
      nextTriggerTime: nextTrigger,
      clearNextTriggerTime: !enabled,
      statusMessage: enabled ? 'Alarm active' : 'Alarm standby',
    );

    if (enabled) {
      _armTimer();
      _startCountdownTicker();
    } else {
      _disarmTimer();
    }
  }

  /// Updates the alarm time (hour and minute) and repeats daily.
  Future<void> setSchedule(int hour, int minute, {bool repeatDaily = true}) async {
    Prefs.scheduledBackupHour = hour;
    Prefs.scheduledBackupMinute = minute;
    Prefs.scheduledBackupRepeatDaily = repeatDaily;

    final nextTrigger = calculateNextTrigger(hour: hour, minute: minute);

    stateNotifier.value = state.copyWith(
      hour: hour,
      minute: minute,
      repeatDaily: repeatDaily,
      nextTriggerTime: nextTrigger,
    );

    if (state.isEnabled) {
      _armTimer();
      _startCountdownTicker();
    }
  }

  /// Arms the internal Dart timer for the next trigger.
  void _armTimer() {
    _alarmTimer?.cancel();
    if (!state.isEnabled || state.nextTriggerTime == null) return;

    final now = DateTime.now();
    final duration = state.nextTriggerTime!.difference(now);

    if (duration.isNegative || duration == Duration.zero) {
      // Trigger immediately if due
      executeBackupWorkflow();
    } else {
      _alarmTimer = Timer(duration, () {
        executeBackupWorkflow();
      });
      debugPrint('[BackupSchedulerService] Armed alarm for ${state.formattedTime} (in ${duration.inMinutes} mins)');
    }
  }

  void _disarmTimer() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    _countdownTicker?.cancel();
    _countdownTicker = null;
  }

  /// Starts a periodic 30-second ticker to update countdown strings in the UI.
  void _startCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.isEnabled && state.nextTriggerTime != null) {
        // Trigger a notifyListeners update to refresh the countdown text
        stateNotifier.value = state.copyWith();
      }
    });
  }

  /// Core Execution Workflow:
  /// 1. Starts automated gallery scan.
  /// 2. Populates all discovered media items into the active upload queue.
  /// 3. Once queue is filled and scan finishes, immediately triggers Telegram upload.
  /// 4. Re-arms for next day's schedule.
  Future<void> executeBackupWorkflow() async {
    if (state.isExecuting) return;

    if (onExecuteWorkflowHook != null) {
      await onExecuteWorkflowHook!();
      return;
    }

    stateNotifier.value = state.copyWith(
      isExecuting: true,
      statusMessage: 'Scanning gallery & discovering new media...',
    );

    try {
      debugPrint('[BackupSchedulerService] Alarm fired! Scanning device media...');
      // 1. Scan device storage and load all new items into the queue
      final newItemsQueued = await MediaScanner.scanForNewMedia(forceFull: false);

      debugPrint('[BackupSchedulerService] Scanned and loaded $newItemsQueued new items into queue.');

      // 2. Fetch fresh stats so UI and SyncEngine have the exact latest counts
      await SyncEngine.fetchCurrentStats(forceDb: true);

      // 3. Queue is loaded! Stop discovery and start uploading to Telegram channel
      stateNotifier.value = state.copyWith(
        statusMessage: 'Queue ready ($newItemsQueued new). Uploading to Telegram...',
      );

      if (!Prefs.uploadPaused) {
        await SyncEngine().startSync();
      }

      // 4. Update last run information
      final now = DateTime.now();

      stateNotifier.value = state.copyWith(
        isExecuting: false,
        statusMessage: 'Scheduled backup completed ($newItemsQueued queued)',
        lastRunTime: now,
        lastRunQueuedCount: newItemsQueued,
        isEnabled: state.repeatDaily ? state.isEnabled : false,
      );
    } catch (e, st) {
      debugPrint('[BackupSchedulerService] Error executing scheduled backup: $e\n$st');
      stateNotifier.value = state.copyWith(
        isExecuting: false,
        statusMessage: 'Backup scan error: $e',
      );
    } finally {
      // Re-arm for next day if recurring is enabled, even after errors
      if (state.repeatDaily && state.isEnabled) {
        final nextTrigger = calculateNextTrigger(fromTime: DateTime.now());
        stateNotifier.value = state.copyWith(nextTriggerTime: nextTrigger);
        _armTimer();
      } else if (!state.repeatDaily) {
        _disarmTimer();
        stateNotifier.value = state.copyWith(
          isEnabled: false,
          clearNextTriggerTime: true,
        );
      }
    }
  }

  void dispose() {
    _disarmTimer();
  }
}
