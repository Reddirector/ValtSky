import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/util/permission_manager.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
  });

  testWidgets('PermissionManager renders onboarding modal with all required Android permissions', (tester) async {
    expect(Prefs.permissionsRequested, false);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => PermissionManager.showPermissionOnboardingModal(context),
                  child: const Text('Open Modal'),
                ),
              ),
            );
          },
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Permissions Required'), findsOneWidget);

    // Verify 4 Inbuilt Permissions:
    // 1. Gallery
    expect(find.text('Gallery (Photos & Videos)'), findsOneWidget);
    // 2. Notifications
    expect(find.text('Notifications'), findsOneWidget);
    // 3. Location
    expect(find.text('Location Access'), findsOneWidget);
    // 4. Background Battery Exemption
    expect(find.text('Background Battery Exemption'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('ALLOW ALL PERMISSIONS'), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);

    // Tap ALLOW ALL PERMISSIONS
    await tester.tap(find.text('ALLOW ALL PERMISSIONS'));
    await tester.pumpAndSettle();

    // Verify preference is updated
    expect(Prefs.permissionsRequested, true);
  });
}
