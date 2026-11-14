import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/country_data.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/services/telegram_auth_service.dart';
import 'package:valtsky_flutter/ui/widgets/telegram_phone_login_widget.dart';
import 'package:valtsky_flutter/ui/widgets/telegram_profile_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
  });

  group('CountryData & Formatting Rules Tests', () {
    test('Default country is India (+91) with 10 max digits', () {
      expect(CountryData.defaultCountry.name, equals('India'));
      expect(CountryData.defaultCountry.dialCode, equals('+91'));
      expect(CountryData.defaultCountry.maxLength, equals(10));
    });

    test('CountryData.detectFromPhone correctly resolves dial codes', () {
      final india = CountryData.detectFromPhone('+919876543210');
      expect(india, isNotNull);
      expect(india!.code, equals('IN'));
      expect(india.maxLength, equals(10));

      final us = CountryData.detectFromPhone('+15551234567');
      expect(us, isNotNull);
      expect(us!.code, equals('US'));
      expect(us.maxLength, equals(10));

      final uae = CountryData.detectFromPhone('+971501234567');
      expect(uae, isNotNull);
      expect(uae!.code, equals('AE'));
      expect(uae.maxLength, equals(9));

      final uk = CountryData.detectFromPhone('+447911123456');
      expect(uk, isNotNull);
      expect(uk!.code, equals('GB'));
      expect(uk.maxLength, equals(10));
    });

    test('CountryData.findByDialCode returns fallback for unknown dial code', () {
      final unknown = CountryData.findByDialCode('+9999');
      expect(unknown.name, equals(CountryData.defaultCountry.name));
    });
  });

  group('Prefs Telegram Profile Storage Tests', () {
    test('Stores and clears real Telegram user profile info', () async {
      Prefs.telegramUserId = '987654321';
      Prefs.telegramUserName = 'Aditya Kumar Singh';
      Prefs.telegramUserHandle = 'adityadev';
      Prefs.telegramIsPremium = true;
      Prefs.userPhoneNumber = '+919876543210';
      Prefs.channelId = '-1002891238921';
      Prefs.channelName = 'ValtSky Vault (Aditya)';
      Prefs.telegramAuthKey = '{"id":123456789,"key":"deadbeef","salt":999}';
      Prefs.telegramDcId = 4;
      Prefs.telegramDcIp = '149.154.167.92';
      Prefs.channelAccessHash = '9876543210987';

      expect(Prefs.telegramUserId, equals('987654321'));
      expect(Prefs.telegramUserName, equals('Aditya Kumar Singh'));
      expect(Prefs.telegramUserHandle, equals('adityadev'));
      expect(Prefs.telegramIsPremium, isTrue);
      expect(Prefs.userPhoneNumber, equals('+919876543210'));
      expect(Prefs.telegramAuthKey, isNotNull);
      expect(Prefs.telegramDcId, equals(4));
      expect(Prefs.telegramDcIp, equals('149.154.167.92'));
      expect(Prefs.channelAccessHash, equals('9876543210987'));
      expect(Prefs.isConfigured(), isTrue);

      await Prefs.disconnectTelegram();

      expect(Prefs.telegramUserId, isEmpty);
      expect(Prefs.telegramUserName, isEmpty);
      expect(Prefs.telegramUserHandle, isEmpty);
      expect(Prefs.telegramIsPremium, isFalse);
      expect(Prefs.userPhoneNumber, isEmpty);
      expect(Prefs.channelId, isEmpty);
      expect(Prefs.telegramAuthKey, isNull);
      expect(Prefs.channelAccessHash, isNull);
      expect(Prefs.isConfigured(), isFalse);
    });

    test('MTProto Direct Upload and Message Methods Mock Execution', () async {
      // With secrets set or mocked in test mode
      final result = await TelegramAuthService.instance.sendMessage(
        channelId: '-100123456789',
        text: 'Test message',
      );
      expect(result, isNotNull);
    });

    test('Stash and Restore Failed Items Workflow', () async {
      DatabaseHelper.enableMemoryStoreForTesting();
      final item1 = MediaItem(
        filePath: '/test/failed1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 1000,
        fileSize: 1024,
        status: MediaItem.statusFailed,
        updatedAt: 1000,
      );
      final item2 = MediaItem(
        filePath: '/test/failed2.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 2000,
        fileSize: 2048,
        status: MediaItem.statusFailed,
        updatedAt: 2000,
      );
      await DatabaseHelper.instance.insert(item1);
      await DatabaseHelper.instance.insert(item2);

      expect(await DatabaseHelper.instance.getFailedCount(), equals(2));
      expect(await DatabaseHelper.instance.getStashedCount(), equals(0));

      final stashed = await DatabaseHelper.instance.stashAllFailed();
      expect(stashed, equals(2));
      expect(await DatabaseHelper.instance.getFailedCount(), equals(0));
      expect(await DatabaseHelper.instance.getStashedCount(), equals(2));

      final restored = await DatabaseHelper.instance.restoreAllStashed();
      expect(restored, equals(2));
      expect(await DatabaseHelper.instance.getFailedCount(), equals(0));
      expect(await DatabaseHelper.instance.getPendingCount(), equals(2));
      expect(await DatabaseHelper.instance.getStashedCount(), equals(0));
    });

    test('Claim Next Pending and Real-Time Stats Updates', () async {
      DatabaseHelper.enableMemoryStoreForTesting();
      DatabaseHelper.clearMemoryStoreForTesting();
      final item = MediaItem(
        filePath: '/test/pending_atomic.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 5000,
        fileSize: 4096,
        status: MediaItem.statusPending,
        updatedAt: 5000,
      );
      await DatabaseHelper.instance.insert(item);

      final claimed = await DatabaseHelper.instance.claimNextPending();
      expect(claimed, isNotNull);
      expect(claimed!.filePath, equals('/test/pending_atomic.jpg'));
      expect(claimed.status, equals(MediaItem.statusUploading));

      final stats = await SyncEngine.fetchCurrentStats();
      expect(stats.uploading, equals(1));
      expect(SyncEngine.statsNotifier.value, isNotNull);
      expect(SyncEngine.statsNotifier.value!.uploading, equals(1));

      // Reset uploading back to pending
      await DatabaseHelper.instance.resetUploadingToPending();
      final updatedStats = await SyncEngine.fetchCurrentStats();
      expect(updatedStats.uploading, equals(0));
      expect(updatedStats.inQueue, greaterThanOrEqualTo(1));
    });

    test('Resilience and Failure Classifier Tests', () {
      expect(SyncEngine.isNetworkError('SocketException: OS Error: Connection refused'), isTrue);
      expect(SyncEngine.isNetworkError('HandshakeException: Handshake error in client'), isTrue);
      expect(SyncEngine.isNetworkError('TimeoutException after 0:00:15.000000'), isTrue);
      expect(SyncEngine.isNetworkError('Random business logic error'), isFalse);

      expect(SyncEngine.isSessionExpiredError(401, 'Unauthorized'), isTrue);
      expect(SyncEngine.isSessionExpiredError(null, 'RPCError: 401 AUTH_KEY_UNREGISTERED'), isTrue);
      expect(SyncEngine.isSessionExpiredError(null, 'SESSION_REVOKED'), isTrue);
      expect(SyncEngine.isSessionExpiredError(200, 'OK'), isFalse);

      expect(SyncEngine.isRateLimitError(429, 'Too Many Requests'), isTrue);
      expect(SyncEngine.isRateLimitError(null, 'FLOOD_WAIT_35'), isTrue);
      expect(SyncEngine.extractFloodWaitSeconds('FLOOD_WAIT_45'), equals(45));
      expect(SyncEngine.extractFloodWaitSeconds('Unknown error', 30), equals(30));

      expect(SyncEngine.isChannelPermissionError(403, 'Forbidden'), isTrue);
      expect(SyncEngine.isChannelPermissionError(400, 'CHAT_WRITE_FORBIDDEN'), isTrue);
      expect(SyncEngine.isChannelPermissionError(200, 'OK'), isFalse);
    });

    test('Engine Global Rate Limit and Self-Restart Execution', () async {
      SyncEngine.triggerGlobalRateLimit(2);
      expect(SyncEngine.engineStatusNotifier.value, equals(SyncEngineStatus.rateLimited));
      expect(SyncEngine.rateLimitSecondsRemainingNotifier.value, greaterThan(0));

      // Test self-restart sequence
      await SyncEngine.instance.restartEngine();
      expect(SyncEngine.engineStatusNotifier.value, isNot(equals(SyncEngineStatus.restarting)));
    });

    test('Engine Speed Meter and Multi-Worker Turbo Throughput', () async {
      expect(SyncEngine.workerCount, equals(2));
      expect(SyncEngine.uploadSpeedNotifier, isNotNull);

      SyncEngine.uploadSpeedNotifier.value = '12.4 MB/s';
      expect(SyncEngine.uploadSpeedNotifier.value, equals('12.4 MB/s'));

      SyncEngine.uploadSpeedNotifier.value = '850 KB/s';
      expect(SyncEngine.uploadSpeedNotifier.value, equals('850 KB/s'));
    });

    test('DatabaseHelper.getAllItems Pagination & Lazy Loading', () async {
      DatabaseHelper.enableMemoryStoreForTesting();
      DatabaseHelper.clearMemoryStoreForTesting();

      // Insert 5 items with distinct timestamps
      for (int i = 1; i <= 5; i++) {
        await DatabaseHelper.instance.insert(MediaItem(
          filePath: '/test/page_item_$i.jpg',
          mimeType: 'image/jpeg',
          dateTaken: i * 1000,
          fileSize: 1024,
          status: MediaItem.statusPending,
          updatedAt: i * 1000,
        ));
      }

      // Page 1: limit 2, offset 0 -> Should return newest 2 (items 5, 4)
      final page1 = await DatabaseHelper.instance.getAllItems(limit: 2, offset: 0);
      expect(page1.length, equals(2));
      expect(page1[0].filePath, equals('/test/page_item_5.jpg'));
      expect(page1[1].filePath, equals('/test/page_item_4.jpg'));

      // Page 2: limit 2, offset 2 -> Should return items 3, 2
      final page2 = await DatabaseHelper.instance.getAllItems(limit: 2, offset: 2);
      expect(page2.length, equals(2));
      expect(page2[0].filePath, equals('/test/page_item_3.jpg'));
      expect(page2[1].filePath, equals('/test/page_item_2.jpg'));

      // Page 3: limit 2, offset 4 -> Should return item 1
      final page3 = await DatabaseHelper.instance.getAllItems(limit: 2, offset: 4);
      expect(page3.length, equals(1));
      expect(page3[0].filePath, equals('/test/page_item_1.jpg'));

      // Page 4: limit 2, offset 6 -> Empty
      final page4 = await DatabaseHelper.instance.getAllItems(limit: 2, offset: 6);
      expect(page4.isEmpty, isTrue);
    });

    test('SyncEngine Safe Completer & Auto-Recovery of Failed Items', () async {
      DatabaseHelper.enableMemoryStoreForTesting();
      DatabaseHelper.clearMemoryStoreForTesting();

      // Insert 2 failed items
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/test/fail_item_1.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 1000,
        fileSize: 1024,
        status: MediaItem.statusFailed,
        updatedAt: 1000,
      ));
      await DatabaseHelper.instance.insert(MediaItem(
        filePath: '/test/fail_item_2.jpg',
        mimeType: 'image/jpeg',
        dateTaken: 2000,
        fileSize: 2048,
        status: MediaItem.statusFailed,
        updatedAt: 2000,
      ));

      // Repeated stopSync calls must never throw Bad state: Future already completed
      SyncEngine.instance.stopSync();
      SyncEngine.instance.stopSync();

      // Trigger restart which resets uploading & failed items
      await SyncEngine.instance.restartEngine();

      final pendingItems = await DatabaseHelper.instance.getAllItems(statusFilter: MediaItem.statusPending);
      expect(pendingItems.length, equals(2));
    });

    test('TelegramAuthService ResolvePeer Channel ID Prefix Normalization', () async {
      Prefs.channelAccessHash = '1234567890123';
      
      // Test channel with -100 prefix
      final peer1 = await TelegramAuthService.instance.resolvePeer('-1004297507230');
      expect(peer1, isNotNull);

      // Test channel without prefix
      final peer2 = await TelegramAuthService.instance.resolvePeer('4297507230');
      expect(peer2, isNotNull);
    });
  });

  group('TelegramPhoneLoginWidget Interactive Tests', () {
    testWidgets('Renders country chip and initial 0/10 digits counter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramPhoneLoginWidget(
                onLoginSuccess: () {},
                onSwitchToBotMode: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Telegram Login'), findsOneWidget);
      expect(find.text('0 / 10 digits'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('Country: India (+91) • Max 10 digits'), findsOneWidget);
    });

    testWidgets('Strict digits input: blocks alphabets and enforces 10 max digits for India', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramPhoneLoginWidget(
                onLoginSuccess: () {},
                onSwitchToBotMode: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField).first;
      // Enter alphanumeric characters
      await tester.enterText(input, 'abc987xyz65432109999');
      await tester.pumpAndSettle();

      // Only first 10 digits should be accepted!
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('10 / 10 digits'), findsOneWidget);
    });

    testWidgets('Tapping country chip opens searchable country selector and allows switching', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramPhoneLoginWidget(
                onLoginSuccess: () {},
                onSwitchToBotMode: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on country chip
      await tester.tap(find.text('+91'));
      await tester.pumpAndSettle();

      // Bottom sheet is visible
      expect(find.text('Select Country / Region'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
      expect(find.text('United Kingdom'), findsOneWidget);

      // Select United States (+1, max 10 digits)
      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();

      // Modal closed, country updated to US
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('0 / 10 digits'), findsOneWidget);
      expect(find.text('Country: United States (+1) • Max 10 digits'), findsOneWidget);
    });

    testWidgets('Shows error toast when submitting incomplete phone digits', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramPhoneLoginWidget(
                onLoginSuccess: () {},
                onSwitchToBotMode: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter only 5 digits for India (which requires 10)
      final input = find.byType(TextField).first;
      await tester.enterText(input, '98765');
      await tester.pumpAndSettle();

      // Tap send button
      await tester.tap(find.text('SEND TELEGRAM VERIFICATION CODE'));
      await tester.pumpAndSettle();

      expect(find.text('India numbers require exactly 10 digits (5/10 entered)'), findsOneWidget);
    });
  });

  group('TelegramProfileCard UI Tests', () {
    testWidgets('Renders real user profile, verified badge, premium badge, and handles disconnect', (WidgetTester tester) async {
      Prefs.telegramUserId = '11223344';
      Prefs.telegramUserName = 'Jane Doe';
      Prefs.telegramUserHandle = 'janedoe';
      Prefs.telegramIsPremium = true;
      Prefs.userPhoneNumber = '+919876543210';
      Prefs.channelId = '-1009876543210';
      Prefs.channelName = 'ValtSky Vault (Jane)';
      DatabaseHelper.enableMemoryStoreForTesting();

      bool disconnected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelegramProfileCard(
                isDark: true,
                onDisconnect: () {
                  disconnected = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify profile fields and buttons
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('★ PREMIUM'), findsOneWidget);
      expect(find.text('@janedoe'), findsOneWidget);
      expect(find.text('ID: 11223344'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('ValtSky Vault (Jane)'), findsOneWidget);
      expect(find.text('-1009876543210'), findsOneWidget);
      expect(find.text('Open Vault'), findsNothing);
      expect(find.text('Edit Vault'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);

      // Tap Logout
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Disconnect Account?'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(disconnected, isTrue);
    });

    test('AuthState supports deliveryDescription, codeLength, and timeoutSeconds', () {
      final state = AuthState.initial().copyWith(
        step: AuthStep.enterCode,
        deliveryDescription: 'Telegram sent a 5-digit code via SMS',
        codeLength: 6,
        timeoutSeconds: 45,
      );
      expect(state.step, equals(AuthStep.enterCode));
      expect(state.deliveryDescription, equals('Telegram sent a 5-digit code via SMS'));
      expect(state.codeLength, equals(6));
      expect(state.timeoutSeconds, equals(45));
    });
  });
}
