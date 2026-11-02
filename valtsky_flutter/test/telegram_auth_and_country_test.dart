import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/country_data.dart';
import 'package:valtsky_flutter/data/prefs.dart';
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
      Prefs.telegramUserName = 'Aditya Sharma';
      Prefs.telegramUserHandle = 'adityadev';
      Prefs.telegramIsPremium = true;
      Prefs.userPhoneNumber = '+919876543210';
      Prefs.channelId = '-1002891238921';
      Prefs.channelName = 'ValtSky Vault (Aditya)';

      expect(Prefs.telegramUserId, equals('987654321'));
      expect(Prefs.telegramUserName, equals('Aditya Sharma'));
      expect(Prefs.telegramUserHandle, equals('adityadev'));
      expect(Prefs.telegramIsPremium, isTrue);
      expect(Prefs.userPhoneNumber, equals('+919876543210'));
      expect(Prefs.isConfigured(), isTrue);

      await Prefs.disconnectTelegram();

      expect(Prefs.telegramUserId, isEmpty);
      expect(Prefs.telegramUserName, isEmpty);
      expect(Prefs.telegramUserHandle, isEmpty);
      expect(Prefs.telegramIsPremium, isFalse);
      expect(Prefs.userPhoneNumber, isEmpty);
      expect(Prefs.channelId, isEmpty);
      expect(Prefs.isConfigured(), isFalse);
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

      // Verify badges and profile fields
      expect(find.text('REAL TELEGRAM ACCOUNT LINKED'), findsOneWidget);
      expect(find.text('DC 1 ACTIVE'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('★ PREMIUM'), findsOneWidget);
      expect(find.text('@janedoe'), findsOneWidget);
      expect(find.text('ID: 11223344'), findsOneWidget);
      expect(find.text('+919876543210'), findsOneWidget);
      expect(find.text('ValtSky Vault (Jane)'), findsOneWidget);
      expect(find.text('-1009876543210'), findsOneWidget);
      expect(find.text('OPEN VAULT CHANNEL'), findsOneWidget);
      expect(find.text('LOGOUT'), findsOneWidget);

      // Tap Logout
      await tester.tap(find.text('LOGOUT'));
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
