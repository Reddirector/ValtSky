import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/ui/widgets/dashboard_control_deck.dart';
import 'package:valtsky_flutter/util/media_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
    MediaScanner.scanHookForTesting = ({bool forceFull = false}) async {
      await DatabaseHelper.instance.insert(
        MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/IMG_TEST_001.jpg',
          mimeType: 'image/jpeg',
          dateTaken: 1000,
          fileSize: 2048,
          status: MediaItem.statusPending,
          updatedAt: 1000,
        ),
      );
      await DatabaseHelper.instance.insert(
        MediaItem(
          filePath: '/storage/emulated/0/DCIM/Camera/VID_TEST_002.mp4',
          mimeType: 'video/mp4',
          dateTaken: 2000,
          fileSize: 4096,
          status: MediaItem.statusPending,
          updatedAt: 2000,
        ),
      );
      return 2;
    };
  });

  tearDown(() {
    MediaScanner.scanHookForTesting = null;
    SyncEngine.instance.stopSync();
  });

  group('Telegram Channel Auto-Scan On Config Tests', () {
    test(
      'Configuring channel via initializeNewVaultSession automatically scans gallery and queues media by default',
      () async {
        // Initial state before configuration: database empty, monitoring false
        expect(await DatabaseHelper.instance.getTotalCount(), 0);
        expect(Prefs.monitoringEnabled, isFalse);

        // Configure Telegram Channel credentials
        Prefs.channelId = '-1002891238921';
        Prefs.channelName = 'ValtSky Private Vault';
        Prefs.botToken = 'mock_bot_token';

        // Trigger vault session initialization (invoked on Telegram channel configuration)
        await SyncEngine.instance.initializeNewVaultSession();

        // 1. Monitoring is automatically stopped once scan finishes and items are in queue
        expect(Prefs.monitoringEnabled, isFalse);
        expect(Prefs.uploadPaused, isFalse);

        // 2. Camera gallery must be automatically scanned and populated into the database
        final totalCount = await DatabaseHelper.instance.getTotalCount();
        expect(totalCount, greaterThan(0));

        // 3. Stats notifier must reflect the newly scanned media items
        final stats = SyncEngine.statsNotifier.value;
        expect(stats, isNotNull);
        expect(stats!.total, equals(totalCount));
      },
    );
  });

  group('Dashboard Quick Controls Layout Tests', () {
    testWidgets(
      'DashboardControlDeck houses only Pause and Stop Process with no Diagnostics or Scan Gallery buttons',
      (WidgetTester tester) async {
        bool pauseToggled = false;
        bool stopTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardControlDeck(
                isConfigured: true,
                isPaused: false,
                onTogglePause: () => pauseToggled = true,
                onStopProcess: () => stopTriggered = true,
              ),
            ),
          ),
        );
        await tester.pump();

        // QUICK CONTROLS header must be present
        expect(find.text('QUICK CONTROLS'), findsOneWidget);

        // Pause and Stop Process must be present
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Stop Process'), findsOneWidget);

        // Scan Gallery and Diagnostics buttons MUST NOT be present
        expect(find.text('Scan Gallery'), findsNothing);
        expect(find.text('Diagnostics'), findsNothing);

        // Verify tap interactions
        await tester.tap(find.text('Pause'));
        expect(pauseToggled, isTrue);

        await tester.tap(find.text('Stop Process'));
        expect(stopTriggered, isTrue);
      },
    );

    testWidgets(
      'DashboardControlDeck renders Resume when isPaused is true',
      (WidgetTester tester) async {
        bool resumeToggled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardControlDeck(
                isConfigured: true,
                isPaused: true,
                onTogglePause: () => resumeToggled = true,
                onStopProcess: () {},
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Pause'), findsNothing);

        await tester.tap(find.text('Resume'));
        expect(resumeToggled, isTrue);
      },
    );
  });
}
