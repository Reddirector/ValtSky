import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/services/backup_scheduler_service.dart';
import 'package:valtsky_flutter/ui/widgets/scheduled_backup_timer_card.dart';
import 'package:valtsky_flutter/util/media_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
    MediaScanner.resetScanCooldown();
    await Prefs.init();
    await BackupSchedulerService.instance.init();
  });

  tearDown(() {
    BackupSchedulerService.instance.dispose();
  });

  group('BackupSchedulerService Logic Tests', () {
    test('calculateNextTrigger returns today if time is in future', () {
      final now = DateTime(2026, 11, 10, 10, 0); // 10:00 AM
      final trigger = BackupSchedulerService.instance.calculateNextTrigger(
        fromTime: now,
        hour: 14, // 2:00 PM
        minute: 30,
      );

      expect(trigger.year, 2026);
      expect(trigger.month, 11);
      expect(trigger.day, 10);
      expect(trigger.hour, 14);
      expect(trigger.minute, 30);
    });

    test('calculateNextTrigger returns tomorrow if time has already passed today', () {
      final now = DateTime(2026, 11, 10, 16, 0); // 4:00 PM
      final trigger = BackupSchedulerService.instance.calculateNextTrigger(
        fromTime: now,
        hour: 2, // 2:00 AM
        minute: 0,
      );

      expect(trigger.year, 2026);
      expect(trigger.month, 11);
      expect(trigger.day, 11); // Next day
      expect(trigger.hour, 2);
      expect(trigger.minute, 0);
    });

    test('ScheduledBackupState formats time string accurately', () {
      const stateMorning = ScheduledBackupState(hour: 2, minute: 5);
      expect(stateMorning.formattedTime, '02:05 AM');

      const stateNoon = ScheduledBackupState(hour: 12, minute: 0);
      expect(stateNoon.formattedTime, '12:00 PM');

      const stateEvening = ScheduledBackupState(hour: 23, minute: 30);
      expect(stateEvening.formattedTime, '11:30 PM');

      const stateMidnight = ScheduledBackupState(hour: 0, minute: 15);
      expect(stateMidnight.formattedTime, '12:15 AM');
    });

    test('ScheduledBackupState generates countdown string', () {
      final now = DateTime.now();
      final inThreeHours = now.add(const Duration(hours: 3, minutes: 25));
      final state = ScheduledBackupState(
        isEnabled: true,
        nextTriggerTime: inThreeHours,
      );
      expect(state.countdownText, matches(RegExp(r'in 3h 2[45]m')));

      const disabledState = ScheduledBackupState(isEnabled: false);
      expect(disabledState.countdownText, 'Alarm off');

      const runningState = ScheduledBackupState(isEnabled: true, isExecuting: true);
      expect(runningState.countdownText, 'Running now');

      final dueState = ScheduledBackupState(
        isEnabled: true,
        nextTriggerTime: now.subtract(const Duration(seconds: 10)),
      );
      expect(dueState.countdownText, 'Starting now...');

      final underOneMinState = ScheduledBackupState(
        isEnabled: true,
        nextTriggerTime: now.add(const Duration(seconds: 40)),
      );
      expect(underOneMinState.countdownText, matches(RegExp(r'in \d+s')));

      final underOneHourState = ScheduledBackupState(
        isEnabled: true,
        nextTriggerTime: now.add(const Duration(minutes: 42)),
      );
      expect(underOneHourState.countdownText, matches(RegExp(r'in 4[12]m')));
    });

    test('clearNextTriggerTime properly sets nextTriggerTime to null', () {
      final now = DateTime.now();
      final state = ScheduledBackupState(
        isEnabled: true,
        nextTriggerTime: now,
      );
      expect(state.nextTriggerTime, isNotNull);

      final clearedState = state.copyWith(clearNextTriggerTime: true);
      expect(clearedState.nextTriggerTime, isNull);
    });

    test('setEnabled and setSchedule update state and persist to Prefs', () async {
      await BackupSchedulerService.instance.setEnabled(true);
      expect(BackupSchedulerService.instance.state.isEnabled, isTrue);
      expect(Prefs.scheduledBackupEnabled, isTrue);

      await BackupSchedulerService.instance.setSchedule(6, 45);
      expect(BackupSchedulerService.instance.state.hour, 6);
      expect(BackupSchedulerService.instance.state.minute, 45);
      expect(BackupSchedulerService.instance.state.formattedTime, '06:45 AM');
      expect(Prefs.scheduledBackupHour, 6);
      expect(Prefs.scheduledBackupMinute, 45);

      await BackupSchedulerService.instance.setEnabled(false);
      expect(BackupSchedulerService.instance.state.isEnabled, isFalse);
      expect(BackupSchedulerService.instance.state.nextTriggerTime, isNull);
      expect(Prefs.scheduledBackupEnabled, isFalse);
    });

    test('executeBackupWorkflow runs real flow, re-arms nextTriggerTime and updates lastRun', () async {
      await BackupSchedulerService.instance.setEnabled(true);
      await BackupSchedulerService.instance.setSchedule(2, 0, repeatDaily: true);

      await BackupSchedulerService.instance.executeBackupWorkflow();

      expect(BackupSchedulerService.instance.state.isExecuting, isFalse);
      expect(BackupSchedulerService.instance.state.lastRunTime, isNotNull);
      expect(BackupSchedulerService.instance.state.nextTriggerTime, isNotNull);

      BackupSchedulerService.instance.dispose();
    });

    test('executeBackupWorkflow with repeatDaily false disarms alarm after run', () async {
      await BackupSchedulerService.instance.setEnabled(true);
      await BackupSchedulerService.instance.setSchedule(2, 0, repeatDaily: false);

      await BackupSchedulerService.instance.executeBackupWorkflow();

      expect(BackupSchedulerService.instance.state.isEnabled, isFalse);
      expect(BackupSchedulerService.instance.state.nextTriggerTime, isNull);

      BackupSchedulerService.instance.dispose();
    });
  });

  group('ScheduledBackupTimerCard Widget Tests', () {
    testWidgets('renders alarm card with clock, toggle and presets', (WidgetTester tester) async {
      await BackupSchedulerService.instance.setSchedule(2, 0);
      await BackupSchedulerService.instance.setEnabled(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduledBackupTimerCard(
              isDark: true,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALARM CLOCK BACKUP'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('Tap to Edit'), findsOneWidget);
      expect(find.text('🌙 2:00 AM (Night)'), findsOneWidget);
      expect(find.text('🌅 6:00 AM (Morning)'), findsOneWidget);
      expect(find.text('🛌 11:30 PM (Bedtime)'), findsOneWidget);
      expect(find.text('Save Alarm Schedule'), findsOneWidget);

      BackupSchedulerService.instance.dispose();
    });

    testWidgets('tapping preset chip updates scheduled time', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduledBackupTimerCard(
              isDark: true,
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 6:00 AM preset
      await tester.tap(find.text('🌅 6:00 AM (Morning)'));
      await tester.pumpAndSettle();

      expect(BackupSchedulerService.instance.state.hour, 6);
      expect(BackupSchedulerService.instance.state.minute, 0);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('AM'), findsOneWidget);

      BackupSchedulerService.instance.dispose();
    });

    testWidgets('ScheduledBackupTimerCard.showModal presents bottom sheet and closes', (WidgetTester tester) async {
      await BackupSchedulerService.instance.setSchedule(2, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScheduledBackupTimerCard.showModal(context),
                child: const Text('Open Alarm Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Alarm Modal'));
      await tester.pumpAndSettle();

      expect(find.text('ALARM CLOCK BACKUP'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('ALARM CLOCK BACKUP'), findsNothing);

      BackupSchedulerService.instance.dispose();
    });
  });
}
