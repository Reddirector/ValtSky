import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/services/telegram_auth_service.dart';
import 'package:valtsky_flutter/ui/views/settings_view.dart';
import 'package:valtsky_flutter/ui/widgets/telegram_profile_card.dart';
import 'package:valtsky_flutter/ui/widgets/valtsky_components.dart';
import 'package:valtsky_flutter/util/formatters.dart';
import 'package:valtsky_flutter/util/theme.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  group('ValtSkyFormatters Unit Tests', () {
    test('formatMediaCount returns exact string when count <= 999', () {
      expect(ValtSkyFormatters.formatMediaCount(0), equals('0'));
      expect(ValtSkyFormatters.formatMediaCount(1), equals('1'));
      expect(ValtSkyFormatters.formatMediaCount(42), equals('42'));
      expect(ValtSkyFormatters.formatMediaCount(208), equals('208'));
      expect(ValtSkyFormatters.formatMediaCount(999), equals('999'));
      expect(ValtSkyFormatters.formatMediaCount(-5), equals('0'));
    });

    test('formatMediaCount returns 999+ when count > 999', () {
      expect(ValtSkyFormatters.formatMediaCount(1000), equals('999+'));
      expect(ValtSkyFormatters.formatMediaCount(1001), equals('999+'));
      expect(ValtSkyFormatters.formatMediaCount(5420), equals('999+'));
      expect(ValtSkyFormatters.formatMediaCount(100000), equals('999+'));
    });

    test('formatBytes formats file sizes accurately', () {
      expect(ValtSkyFormatters.formatBytes(0), equals('0 B'));
      expect(ValtSkyFormatters.formatBytes(1024), equals('1.0 KB'));
      expect(ValtSkyFormatters.formatBytes(1048576 * 25), equals('25.0 MB'));
      expect(ValtSkyFormatters.formatBytes(1073741824), equals('1.0 GB'));
    });
  });

  group('StatTile 999+ formatting', () {
    testWidgets('StatTile displays 999+ when value > 999', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: const Scaffold(
            body: StatTile(
              label: 'PHOTOS IN QUEUE',
              value: 1450,
              icon: Icons.photo_library_outlined,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('999+'), findsOneWidget);
      expect(find.text('1450'), findsNothing);
    });

    testWidgets('StatTile displays exact number when value <= 999', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: const Scaffold(
            body: StatTile(
              label: 'PHOTOS IN QUEUE',
              value: 208,
              icon: Icons.photo_library_outlined,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('208'), findsOneWidget);
      expect(find.text('999+'), findsNothing);
    });
  });

  group('TelegramProfileCard Redesign & Edit Mode', () {
    testWidgets('Renders user profile, vault size, and no security encryption line', (WidgetTester tester) async {
      Prefs.authMethod = 'phone';
      Prefs.userPhoneNumber = '+919876543210';
      Prefs.telegramUserId = '88990011';
      Prefs.telegramUserName = 'Alice Smith';
      Prefs.telegramUserHandle = 'alicesmith';
      Prefs.channelId = '-1001234567890';
      Prefs.channelName = 'Alice Cloud Vault';

      // Insert 2 done items in DB
      final now = DateTime.now().millisecondsSinceEpoch;
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/storage/IMG_01.jpg',
        mimeType: 'image/jpeg',
        dateTaken: now,
        fileSize: 10 * 1024 * 1024,
        status: MediaItem.statusDone,
        updatedAt: now,
      ));

      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramProfileCard(
                isDark: false,
                onDisconnect: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify fields
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('@alicesmith'), findsOneWidget);
      expect(find.text('ID: 88990011'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('Alice Cloud Vault'), findsOneWidget);
      expect(find.text('-1001234567890'), findsOneWidget);

      // Verify Vault Size is shown
      expect(find.text('VAULT SIZE'), findsOneWidget);

      // Verify security encryption line is REMOVED
      expect(find.text('SECURITY ENCRYPTION'), findsNothing);
      expect(find.text('MTProto 2.0 (Diffie-Hellman 2048-bit)'), findsNothing);

      // Verify Edit Vault and Open Vault buttons are REMOVED entirely
      expect(find.text('Edit Vault'), findsNothing);
      expect(find.text('Open Vault'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('Profile displays cleanly with prominent Spotify-style Logout button and no edit controls', (WidgetTester tester) async {
      Prefs.authMethod = 'phone';
      Prefs.userPhoneNumber = '+919876543210';
      Prefs.telegramUserId = '88990011';
      Prefs.telegramUserName = 'Alice Smith';
      Prefs.channelId = '-1001234567890';
      Prefs.channelName = 'Alice Vault';

      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramProfileCard(
                isDark: false,
                onDisconnect: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no Edit Vault or Open Vault buttons exist
      expect(find.text('Edit Vault'), findsNothing);
      expect(find.text('Open Vault'), findsNothing);
      expect(find.text('EDIT VAULT NAME'), findsNothing);

      // Verify Logout button exists
      expect(find.text('Logout'), findsOneWidget);
    });

    test('renameVaultChannel renames existing old channel without creating a new channel', () async {
      Prefs.channelId = '-1002938475612';
      Prefs.channelName = 'Old Vault Title';

      final success = await TelegramAuthService.instance.renameVaultChannel(
        channelId: Prefs.channelId,
        newTitle: 'Renamed Vault 2026',
      );

      expect(success, isTrue);
      // Verify channelId remains the same old channel (no new channel is created)
      expect(Prefs.channelId, equals('-1002938475612'));
    });
  });

  group('SettingsView Upload Engine Minimized & API Server Removed', () {
    testWidgets('SettingsView displays minimized 3-button engine and hides API server input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.light(),
          home: Scaffold(
            body: SettingsView(
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 3 engine buttons exist
      expect(find.text('Lossless'), findsOneWidget);
      expect(find.text('High Speed'), findsOneWidget);
      expect(find.text('Auto Chunk'), findsOneWidget);

      // Verify API Server input and description are completely removed from UI
      expect(find.text('https://api.telegram.org'), findsNothing);
      expect(find.text('Custom endpoint for direct 2GB uploads.'), findsNothing);

      // Tap High Speed
      await tester.tap(find.text('High Speed'));
      await tester.pumpAndSettle();
      expect(Prefs.useOriginalQuality, isFalse);

      // Tap Lossless
      await tester.tap(find.text('Lossless'));
      await tester.pumpAndSettle();
      expect(Prefs.useOriginalQuality, isTrue);

      // Tap Auto Chunk
      final initialChunking = Prefs.enableChunking;
      await tester.tap(find.text('Auto Chunk'));
      await tester.pumpAndSettle();
      expect(Prefs.enableChunking, equals(!initialChunking));
    });

    testWidgets('Removes Lock Configuration, spaces network buttons evenly, and makes Vault Privacy Lock a separate card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.dark(),
          home: Scaffold(
            body: SettingsView(
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Lock Configuration button is completely removed
      expect(find.text('Lock Configuration'), findsNothing);
      expect(find.text('Prevent edits while syncing.'), findsNothing);

      // 2. Network & Security Rules has only Wi-Fi, Both, and Data, evenly spaced
      expect(find.text('Network & Security Rules'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);

      final segmentedFinder = find.byType(SegmentedButton<NetworkTypeChoice>);
      expect(segmentedFinder, findsOneWidget);
      final SegmentedButton<NetworkTypeChoice> segmentedButton = tester.widget(segmentedFinder);
      expect(segmentedButton.expandedInsets, equals(EdgeInsets.zero));

      // 3. Vault Privacy Lock is rendered in its own dedicated card
      expect(find.text('Vault Privacy Lock'), findsWidgets);
      expect(find.text('Protect vault with secure PIN code.'), findsOneWidget);
    });

    testWidgets('Device Permissions section is removed from SettingsView UI and handled on first launch', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ValtSkyTheme.dark(),
          home: Scaffold(
            body: SettingsView(
              onDataChanged: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Device Permissions section is removed from Settings UI
      expect(find.text('Device Permissions'), findsNothing);
      expect(find.text('MANAGE & GRANT PERMISSIONS'), findsNothing);
      expect(find.text('Gallery Access'), findsNothing);
      expect(find.text('Battery Exemption'), findsNothing);
    });
  });
}
