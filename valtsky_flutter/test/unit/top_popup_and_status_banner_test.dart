import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/ui/views/activity_view.dart';
import 'package:valtsky_flutter/ui/widgets/dashboard_status_banner.dart';
import 'package:valtsky_flutter/ui/widgets/lazy_media_list_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
    SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
    SyncEngine.engineStatusMessageNotifier.value = '';
    SyncEngine.rateLimitSecondsRemainingNotifier.value = 0;
  });

  tearDown(() {
    DatabaseHelper.clearMemoryStoreForTesting();
    SyncEngine.engineStatusNotifier.value = SyncEngineStatus.idle;
  });

  group('DashboardStatusBanner Dismissibility & Alert Tests', () {
    testWidgets('Renders nothing when status is idle, active, or paused', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardStatusBanner), findsOneWidget);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('Renders rate limit banner and dismisses upon clicking close button', (tester) async {
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.rateLimited;
      SyncEngine.rateLimitSecondsRemainingNotifier.value = 42;
      SyncEngine.engineStatusMessageNotifier.value = 'Telegram flood wait active';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('42s remaining'), findsOneWidget);
      expect(find.text('Telegram flood wait active'), findsOneWidget);
      expect(find.byTooltip('Dismiss alert'), findsOneWidget);

      // Tap dismiss icon button
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();

      // Banner is now dismissed
      expect(find.text('42s remaining'), findsNothing);
      expect(find.text('Telegram flood wait active'), findsNothing);
    });

    testWidgets('Resets dismissed status when engine transitions to another status and back', (tester) async {
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.rateLimited;
      SyncEngine.rateLimitSecondsRemainingNotifier.value = 10;
      SyncEngine.engineStatusMessageNotifier.value = 'Temporary rate limit';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dismiss the rate limit banner
      expect(find.text('10s remaining'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss alert'));
      await tester.pumpAndSettle();
      expect(find.text('10s remaining'), findsNothing);

      // Transition to active/idle (clears dismissed state)
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.active;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subsequent rate limit event re-displays the banner
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.rateLimited;
      SyncEngine.rateLimitSecondsRemainingNotifier.value = 25;
      SyncEngine.engineStatusMessageNotifier.value = 'New flood wait event';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('25s remaining'), findsOneWidget);
      expect(find.text('New flood wait event'), findsOneWidget);
    });

    testWidgets('Renders offline banner and allows retry callback', (tester) async {
      bool retryCalled = false;
      SyncEngine.engineStatusNotifier.value = SyncEngineStatus.offline;
      SyncEngine.engineStatusMessageNotifier.value = 'Waiting for network connection...';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardStatusBanner(
              onNavigateToSettings: () {},
              onCheckNetwork: () => retryCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Waiting for network connection...'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retryCalled, isTrue);
    });
  });

  group('LazyMediaListSheet Short Window & Activity Action Deck Tests', () {
    testWidgets('LazyMediaListSheet opens within compact height constraint', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  LazyMediaListSheet.show(
                    context,
                    title: 'Photos in Queue',
                    statusFilter: 'PENDING',
                    isVideo: false,
                    icon: Icons.photo_library_outlined,
                  );
                },
                child: const Text('Open Short Popup'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Short Popup'));
      await tester.pumpAndSettle();

      expect(find.text('Photos in Queue'), findsOneWidget);
      expect(find.byType(LazyMediaListSheet), findsOneWidget);

      // Verify the sheet height does not stretch to the top (maxHeight <= 440)
      final sheetFinder = find.byType(LazyMediaListSheet);
      final size = tester.getSize(sheetFinder);
      expect(size.height, lessThanOrEqualTo(440.0));
    });

    testWidgets('ActivityView action deck has Clear Queue and no dead Scan Gallery button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityView(onDataChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear Queue'), findsOneWidget);
      // Scan Gallery was removed from ActivityView per user request
      expect(find.text('Scan Gallery'), findsNothing);
    });
  });
}
