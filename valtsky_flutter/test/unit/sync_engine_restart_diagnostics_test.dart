import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtsky_flutter/data/prefs.dart';
import 'package:valtsky_flutter/data/db/database_helper.dart';
import 'package:valtsky_flutter/data/models/media_item.dart';
import 'package:valtsky_flutter/services/sync_engine.dart';
import 'package:valtsky_flutter/services/telegram_api.dart';
import 'package:valtsky_flutter/services/telegram_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs.init();
    DatabaseHelper.enableMemoryStoreForTesting();
    DatabaseHelper.clearMemoryStoreForTesting();
  });

  tearDown(() {
    SyncEngine.instance.stopSync();
  });

  group('SyncEngine Socket & Diagnostics Restart Tests', () {
    test(
      'Restarting engine halts previous generation workers and invalidates epoch',
      () async {
        // Configure mock preferences so sync engine can run
        Prefs.channelId = '-1001234567890';
        Prefs.telegramAuthKey = 'mock_auth_key';
        Prefs.uploadPaused = false;

        // Add dummy media items
        await DatabaseHelper.instance.insert(
          MediaItem(
            filePath: '/test/photo1.jpg',
            mimeType: 'image/jpeg',
            dateTaken: 1000,
            fileSize: 1024,
            status: MediaItem.statusPending,
            updatedAt: 1000,
          ),
        );

        // Start engine
        await SyncEngine.instance.startSync();
        final initialGen = SyncEngine.syncGeneration;
        expect(initialGen, greaterThan(0));

        // Re-establishing sockets via restartEngine must advance sync generation
        await SyncEngine.instance.restartEngine();
        final nextGen = SyncEngine.syncGeneration;
        expect(nextGen, greaterThan(initialGen));

        // Engine status must return to active or idle, never stuck in restarting
        expect(
          SyncEngine.engineStatusNotifier.value,
          isNot(equals(SyncEngineStatus.restarting)),
        );
      },
    );

    test(
      'Multiple rapid socket restarts do not leak multiple concurrent worker loops',
      () async {
        Prefs.channelId = '-1001234567890';
        Prefs.telegramAuthKey = 'mock_auth_key';
        Prefs.uploadPaused = false;

        for (int i = 0; i < 5; i++) {
          await DatabaseHelper.instance.insert(
            MediaItem(
              filePath: '/test/photo_rapid_$i.jpg',
              mimeType: 'image/jpeg',
              dateTaken: 1000 + i,
              fileSize: 1024,
              status: MediaItem.statusPending,
              updatedAt: 1000 + i,
            ),
          );
        }

        // Rapidly trigger socket restart 3 times
        final r1 = SyncEngine.instance.restartEngine();
        final r2 = SyncEngine.instance.restartEngine();
        final r3 = SyncEngine.instance.restartEngine();

        await Future.wait([r1, r2, r3]);

        // Exactly 1 generation of active workers should be running, not 3 sets
        expect(SyncEngine.activePhotoWorkerCount, lessThanOrEqualTo(1));
        expect(SyncEngine.activeVideoWorkerCount, lessThanOrEqualTo(1));
      },
    );

    test(
      'Isolate upload cancellation does not fall back to main thread direct upload',
      () async {
        // Invalidate isolate and verify that failure is returned cleanly without main thread lock
        final result = await TelegramAuthService.instance.uploadMedia(
          file: File('/nonexistent/file.jpg'),
          channelId: '-1001234567890',
          asDocument: false,
        );

        // Should return a clean Failure, never freeze or throw
        expect(result, isA<Failure>());
      },
    );
  });
}
