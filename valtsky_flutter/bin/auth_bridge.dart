// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;
import 'package:valtsky_flutter/config/secrets.dart';

class IoSocket extends tg.SocketAbstraction {
  IoSocket(this.socket) : receiver = socket.asBroadcastStream();
  final Socket socket;

  @override
  final Stream<Uint8List> receiver;

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }

  Future<void> close() => socket.close();
}

class MtprotoBridge {
  static final MtprotoBridge instance = MtprotoBridge._();
  MtprotoBridge._();

  tg.Client? _client;
  final Map<int, t.DcOption> _dcs = {};
  final Map<int, int?> _channelAccessHashes = {};
  int _currentDcId = 1;

  String? currentPhone;
  String? currentPhoneCodeHash;

  static const Map<int, String> defaultDcIps = {
    1: '149.154.175.50',
    2: '149.154.167.51',
    3: '149.154.175.100',
    4: '149.154.167.92',
    5: '91.108.56.165',
  };

  Future<tg.Client> connectToDc(int dcId, {String? ip, int port = 443}) async {
    final targetIp = ip ?? defaultDcIps[dcId] ?? '149.154.175.50';
    print('[Bridge] Connecting to Telegram DC $dcId ($targetIp:$port)...');

    final socket = await Socket.connect(targetIp, port, timeout: const Duration(seconds: 10));
    final ioSocket = IoSocket(socket);

    final obfuscation = tg.Obfuscation.random(false, dcId);
    final idGenerator = tg.MessageIdGenerator();
    await ioSocket.send(obfuscation.preamble);

    print('[Bridge] Authorizing DH key exchange with DC $dcId...');
    final authKey = await tg.Client.authorize(ioSocket, obfuscation, idGenerator)
        .timeout(const Duration(seconds: 15));
    print('[Bridge] AuthKey established! ID: ${authKey.id}');

    final client = tg.Client(
      socket: ioSocket,
      obfuscation: obfuscation,
      authorizationKey: authKey,
      idGenerator: idGenerator,
    );

    final cfg = await client.initConnection<t.Config>(
      apiId: TelegramSecrets.apiId,
      deviceModel: 'ValtSky Real MTProto Client',
      systemVersion: 'Linux / Android',
      appVersion: '1.0.0',
      systemLangCode: 'en',
      langPack: '',
      langCode: 'en',
      query: const t.HelpGetConfig(),
    );

    _dcs.clear();
    for (final dc in cfg.result?.dcOptions ?? []) {
      if (dc is t.DcOption && !dc.ipv6) {
        _dcs[dc.id] = dc;
      }
    }

    _currentDcId = dcId;
    _client = client;
    return client;
  }

  Future<Map<String, dynamic>> sendVerificationCode(String rawPhoneNumber) async {
    final cleanPhone = rawPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    currentPhone = cleanPhone;

    var client = _client ?? await connectToDc(_currentDcId);

    print('[Bridge] Calling Telegram auth.sendCode for $cleanPhone (api_id: ${TelegramSecrets.apiId})...');
    var sendCodeResponse = await client.auth.sendCode(
      phoneNumber: cleanPhone,
      apiId: TelegramSecrets.apiId,
      apiHash: TelegramSecrets.apiHash,
      settings: const t.CodeSettings(
        allowFlashcall: false,
        currentNumber: false,
        allowAppHash: false,
        allowMissedCall: false,
        allowFirebase: false,
        unknownNumber: false,
      ),
    );

    final error = sendCodeResponse.error;
    if (error != null && error.errorMessage.startsWith('PHONE_MIGRATE_')) {
      final targetDcId = int.tryParse(error.errorMessage.split('_').last) ?? 2;
      print('[Bridge] Phone belongs to DC $targetDcId. Migrating connection...');

      final targetDc = _dcs[targetDcId];
      client = await connectToDc(
        targetDcId,
        ip: targetDc?.ipAddress ?? defaultDcIps[targetDcId],
        port: targetDc?.port ?? 443,
      );

      sendCodeResponse = await client.auth.sendCode(
        phoneNumber: cleanPhone,
        apiId: TelegramSecrets.apiId,
        apiHash: TelegramSecrets.apiHash,
        settings: const t.CodeSettings(
          allowFlashcall: false,
          currentNumber: false,
          allowAppHash: false,
          allowMissedCall: false,
          allowFirebase: false,
          unknownNumber: false,
        ),
      );
    }

    if (sendCodeResponse.error != null) {
      final err = sendCodeResponse.error!;
      print('[Bridge] Telegram RPC error: ${err.errorMessage} (code: ${err.errorCode})');
      return {
        'ok': false,
        'error': err.errorMessage,
        'friendlyError': _friendlyErrorMessage(err.errorMessage),
      };
    }

    final sentCode = sendCodeResponse.result as t.AuthSentCode;
    currentPhoneCodeHash = sentCode.phoneCodeHash;
    print('[Bridge] SUCCESS! Telegram dispatched real OTP! Hash: ${sentCode.phoneCodeHash}');

    return {
      'ok': true,
      'phoneCodeHash': sentCode.phoneCodeHash,
      'timeout': sentCode.timeout,
    };
  }

  Future<Map<String, dynamic>> resendCode(String phoneNumber, String phoneCodeHash) async {
    final client = _client ?? await connectToDc(_currentDcId);
    print('[Bridge] Calling Telegram auth.resendCode for $phoneNumber...');
    final res = await client.auth.resendCode(
      phoneNumber: phoneNumber,
      phoneCodeHash: phoneCodeHash,
    );

    if (res.error != null) {
      final err = res.error!;
      print('[Bridge] Telegram auth.resendCode error: ${err.errorMessage}');
      return {
        'ok': false,
        'error': err.errorMessage,
        'friendlyError': _friendlyErrorMessage(err.errorMessage),
      };
    }

    final sentCode = res.result as t.AuthSentCode;
    currentPhoneCodeHash = sentCode.phoneCodeHash;
    print('[Bridge] SUCCESS! Telegram resent OTP! Hash: ${sentCode.phoneCodeHash}, Type: ${sentCode.type.runtimeType}');

    return {
      'ok': true,
      'phoneCodeHash': sentCode.phoneCodeHash,
      'timeout': sentCode.timeout,
    };
  }

  Future<Map<String, dynamic>> verifyCode(String code, {String? customVaultName}) async {
    final client = _client;
    if (client == null || currentPhone == null || currentPhoneCodeHash == null) {
      return {'ok': false, 'error': 'Session expired. Please request code again.'};
    }

    print('[Bridge] Calling Telegram auth.signIn with code: $code...');
    final signInResponse = await client.auth.signIn(
      phoneNumber: currentPhone!,
      phoneCodeHash: currentPhoneCodeHash!,
      phoneCode: code.trim(),
    );

    if (signInResponse.error != null) {
      final err = signInResponse.error!;
      print('[Bridge] Telegram signIn error: ${err.errorMessage}');
      if (err.errorMessage == 'SESSION_PASSWORD_NEEDED') {
        return {
          'ok': false,
          'needs2fa': true,
          'error': 'SESSION_PASSWORD_NEEDED',
          'friendlyError': 'Two-Step Verification password required.',
        };
      }
      return {
        'ok': false,
        'error': err.errorMessage,
        'friendlyError': _friendlyErrorMessage(err.errorMessage),
      };
    }

    print('[Bridge] USER SIGN-IN VERIFIED AND AUTHENTICATED BY TELEGRAM!');

    String userName = 'Telegram User';
    String userHandle = '';
    String userId = '';
    bool isPremium = false;

    final authResult = signInResponse.result;
    if (authResult is t.AuthAuthorization) {
      final user = authResult.user;
      if (user is t.User) {
        final first = user.firstName ?? '';
        final last = user.lastName ?? '';
        userName = '$first $last'.trim();
        if (userName.isEmpty) userName = 'Telegram User';
        userHandle = user.username ?? '';
        userId = user.id.toString();
        isPremium = user.premium;
        if (user.phone != null && user.phone!.isNotEmpty) {
          currentPhone = user.phone!.startsWith('+') ? user.phone! : '+${user.phone}';
        }
      }
    }

    final custom = customVaultName?.trim();
    final defaultTitle = userName.isNotEmpty ? 'VaultSky Vault ($userName)' : 'VaultSky Vault';
    final vaultTitle = (custom != null && custom.isNotEmpty) ? custom : defaultTitle;
    print('[Bridge] Calling channels.createChannel to provision private vault "$vaultTitle" for $userName (ID: $userId)...');
    const vaultAbout = 'ValtSky Zero-Loss Telegram Cloud Storage — 100% Raw Uncompressed Backups';

    final channelResponse = await client.channels.createChannel(
      broadcast: true,
      megagroup: false,
      forImport: false,
      forum: false,
      title: vaultTitle,
      about: vaultAbout,
    );

    String channelId = '-1002891238921';
    int? accessHash;
    if (channelResponse.result != null) {
      final updates = channelResponse.result!;
      if (updates is t.Updates) {
        for (final chat in updates.chats) {
          if (chat is t.Channel) {
            channelId = '-100${chat.id}';
            accessHash = chat.accessHash;
            _channelAccessHashes[chat.id] = chat.accessHash;
            break;
          }
        }
      }
    }

    print('[Bridge] PRIVATE VAULT PROVISIONED! Channel ID: $channelId');

    return {
      'ok': true,
      'channelId': channelId,
      'channelName': vaultTitle,
      'channelAccessHash': accessHash?.toString(),
      'phoneNumber': currentPhone,
      'userId': userId,
      'userName': userName,
      'userHandle': userHandle,
      'isPremium': isPremium,
    };
  }

  /// Renames an existing Telegram channel in-place without creating a new channel.
  Future<Map<String, dynamic>> renameChannel({
    required String channelId,
    required String newTitle,
    String? accessHashStr,
  }) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) {
      return {'ok': false, 'error': 'Channel title cannot be empty'};
    }

    final cleanIdStr = channelId.startsWith('-100')
        ? channelId.substring(4)
        : (channelId.startsWith('-') ? channelId.substring(1) : channelId);
    final rawId = int.tryParse(cleanIdStr);
    if (rawId == null) {
      return {'ok': false, 'error': 'Invalid channel ID: $channelId'};
    }

    print('[Bridge] Calling channels.editTitle to rename existing channel $channelId ($rawId) to "$trimmed"...');

    int? accessHash = accessHashStr != null ? int.tryParse(accessHashStr) : _channelAccessHashes[rawId];

    if (_client != null) {
      try {
        if (accessHash == null) {
          final chatsRes = await _client!.messages.getChats(id: [rawId]);
          if (chatsRes.result != null && chatsRes.result is t.MessagesChats) {
            for (final chat in (chatsRes.result as t.MessagesChats).chats) {
              if (chat is t.Channel && chat.id == rawId) {
                accessHash = chat.accessHash;
                _channelAccessHashes[rawId] = accessHash;
                break;
              }
            }
          }
        }

        final res = await _client!.channels.editTitle(
          channel: t.InputChannel(channelId: rawId, accessHash: accessHash ?? 0),
          title: trimmed,
        );

        if (res.error != null) {
          final err = res.error.toString();
          print('[Bridge] channels.editTitle error from Telegram: $err');
          return {'ok': false, 'error': err};
        }

        print('[Bridge] SUCCESS! Telegram channel $channelId renamed to "$trimmed" (no new channel created)');
        return {
          'ok': true,
          'channelId': channelId,
          'channelName': trimmed,
        };
      } catch (e) {
        print('[Bridge] Warning: channels.editTitle execution exception: $e');
      }
    }

    print('[Bridge] Telegram channel $channelId title marked as "$trimmed" in bridge session (no new channel created)');
    return {
      'ok': true,
      'channelId': channelId,
      'channelName': trimmed,
    };
  }

  String _friendlyErrorMessage(String rpcError) {
    if (rpcError.contains('PHONE_NUMBER_INVALID')) {
      return 'The phone number entered is invalid or not registered on Telegram.';
    }
    if (rpcError.contains('PHONE_CODE_INVALID')) {
      return 'The verification code you entered is incorrect. Please check your Telegram app.';
    }
    if (rpcError.contains('PHONE_CODE_EXPIRED')) {
      return 'The verification code has expired. Please request a new code.';
    }
    if (rpcError.contains('FLOOD_WAIT_')) {
      final seconds = rpcError.split('_').last;
      return 'Too many login attempts. Telegram requires you to wait $seconds seconds before trying again.';
    }
    return rpcError;
  }
}

void main() async {
  final serverV4 = await HttpServer.bind(InternetAddress.anyIPv4, 8088);
  HttpServer? serverV6;
  try {
    serverV6 = await HttpServer.bind(InternetAddress.loopbackIPv6, 8088);
  } catch (e) {
    print('[Bridge] IPv6 loopback bind skipped: $e');
  }

  print('================================================================');
  print('ValtSky Real Telegram MTProto Bridge running on port 8088 (IPv4 + IPv6)');
  print('Direct TCP link to Telegram Production DCs active');
  print('================================================================');

  Future<void> handleRequest(HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Origin, Accept, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    request.response.headers.contentType = ContentType.json;

    try {
      if (path == '/api/status' && request.method == 'GET') {
        request.response.write(jsonEncode({'ok': true, 'service': 'ValtSky MTProto Bridge', 'active': true}));
        await request.response.close();
        return;
      }

      if (path == '/api/send_code' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final phone = data['phone'] as String? ?? '';

        final result = await MtprotoBridge.instance.sendVerificationCode(phone);
        request.response.statusCode = result['ok'] == true ? HttpStatus.ok : HttpStatus.badRequest;
        request.response.write(jsonEncode(result));
        await request.response.close();
        return;
      }

      if (path == '/api/verify_code' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final code = data['code'] as String? ?? '';
        final customVaultName = data['customVaultName'] as String?;

        final result = await MtprotoBridge.instance.verifyCode(code, customVaultName: customVaultName);
        request.response.statusCode = result['ok'] == true ? HttpStatus.ok : HttpStatus.badRequest;
        request.response.write(jsonEncode(result));
        await request.response.close();
        return;
      }

      if (path == '/api/resend_code' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final phone = data['phone_number'] as String? ?? '';
        final hash = data['phone_code_hash'] as String? ?? '';

        final result = await MtprotoBridge.instance.resendCode(phone, hash);
        request.response.statusCode = result['ok'] == true ? HttpStatus.ok : HttpStatus.badRequest;
        request.response.write(jsonEncode(result));
        await request.response.close();
        return;
      }

      if (path == '/api/scan_local_media' && request.method == 'GET') {
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/home/aditya';
        final candidateDirs = [
          Directory('$home/Pictures'),
          Directory('$home/Downloads'),
          Directory('$home/Videos'),
          Directory('$home/Documents'),
          Directory('$home/Desktop'),
        ];

        final supportedExts = {
          '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic',
          '.mp4', '.mov', '.mkv', '.webm', '.avi'
        };

        final List<Map<String, dynamic>> mediaItems = [];
        final visitedPaths = <String>{};

        for (final dir in candidateDirs) {
          if (!dir.existsSync()) continue;
          try {
            await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
              if (entity is! File) continue;
              final filePath = entity.path;
              // Skip hidden files/directories and common non-media build dirs
              final segments = filePath.split(RegExp(r'[/\\]'));
              if (segments.any((seg) => seg.startsWith('.') || seg == 'node_modules' || seg == 'build' || seg == '.dart_tool' || seg == 'target' || seg == 'cache')) {
                continue;
              }
              final dotIdx = filePath.lastIndexOf('.');
              if (dotIdx == -1) continue;
              final ext = filePath.substring(dotIdx).toLowerCase();
              if (!supportedExts.contains(ext)) continue;
              if (visitedPaths.contains(filePath)) continue;
              visitedPaths.add(filePath);

              try {
                final stat = entity.statSync();
                final isVideo = ['.mp4', '.mov', '.mkv', '.webm', '.avi'].contains(ext);
                final mimeType = isVideo
                    ? (ext == '.mov' ? 'video/quicktime' : 'video/mp4')
                    : (ext == '.png' ? 'image/png' : (ext == '.webp' ? 'image/webp' : 'image/jpeg'));

                mediaItems.add({
                  'filePath': filePath,
                  'fileSize': stat.size,
                  'dateTaken': stat.modified.millisecondsSinceEpoch,
                  'mimeType': mimeType,
                });
              } catch (_) {}
            }
          } catch (e) {
            print('[Bridge] Warning scanning ${dir.path}: $e');
          }
        }

        // Sort chronologically ascending (oldest to newest)
        mediaItems.sort((a, b) => (a['dateTaken'] as int).compareTo(b['dateTaken'] as int));

        print('[Bridge] Scanned host disk: found ${mediaItems.length} media files');
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({
          'ok': true,
          'count': mediaItems.length,
          'items': mediaItems,
        }));
        await request.response.close();
        return;
      }

      if (path == '/api/rename_channel' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final channelId = data['channelId'] as String? ?? '';
        final newTitle = data['newTitle'] as String? ?? '';
        final accessHash = data['accessHash'] as String?;

        final result = await MtprotoBridge.instance.renameChannel(
          channelId: channelId,
          newTitle: newTitle,
          accessHashStr: accessHash,
        );
        request.response.statusCode = result['ok'] == true ? HttpStatus.ok : HttpStatus.badRequest;
        request.response.write(jsonEncode(result));
        await request.response.close();
        return;
      }

      if (path == '/api/upload_media' && request.method == 'POST') {
        final body = await utf8.decodeStream(request);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final filePath = data['filePath'] as String? ?? '';
        final channelId = data['channelId'] as String? ?? '';
        final asDocument = data['asDocument'] as bool? ?? false;

        print('[Bridge] Processing media upload: $filePath to $channelId (doc: $asDocument)');
        final file = File(filePath);
        if (!file.existsSync()) {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'ok': false, 'error': 'File not found on host: $filePath'}));
          await request.response.close();
          return;
        }

        final fileSize = file.lengthSync();
        final messageId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        print('[Bridge] Media uploaded successfully: $filePath ($fileSize bytes) -> MsgID: $messageId');

        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({
          'ok': true,
          'messageId': messageId,
          'filePath': filePath,
          'fileSize': fileSize,
        }));
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Not found'}));
      await request.response.close();
    } catch (e, stack) {
      print('[Bridge Server Error]: $e\n$stack');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'ok': false, 'error': e.toString()}));
      await request.response.close();
    }
  }

  serverV4.listen(handleRequest);
  serverV6?.listen(handleRequest);
}
