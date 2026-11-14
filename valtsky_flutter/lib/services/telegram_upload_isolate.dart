import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:t/t.dart' as t;
import 'package:tg/tg.dart' as tg;
import '../util/file_security_guard.dart';
import 'telegram_api.dart';
import 'telegram_transport.dart';

/// Initialization payload sent to the background isolate.
class IsolateInitMessage {
  final SendPort sendPort;
  final int workerIndex;
  final String dcIp;
  final int dcId;
  final String savedAuthKey;
  final int apiId;
  final String apiHash;

  IsolateInitMessage({
    required this.sendPort,
    required this.workerIndex,
    required this.dcIp,
    required this.dcId,
    required this.savedAuthKey,
    required this.apiId,
    required this.apiHash,
  });
}

/// Dedicated background Isolate worker client for MTProto uploads.
/// Offloads file chunking, MTProto TL serialization, and PointyCastle pure-Dart
/// AES-256-IGE / SHA-256 software cryptography to a secondary OS thread, keeping
/// the Flutter root isolate at a silky-smooth 120 FPS.
class IsolateUploadClient {
  final int workerIndex;
  final Isolate _isolate;
  final SendPort _commandPort;
  final ReceivePort _eventPort;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;

  Completer<UploadResult>? _currentJobCompleter;
  void Function(int sent, int total)? _currentProgressCallback;
  bool _isDisposed = false;

  IsolateUploadClient._(
    this.workerIndex,
    this._isolate,
    this._commandPort,
    this._eventPort,
    this._errorPort,
    this._exitPort,
  );

  static Future<IsolateUploadClient> spawn({
    required int workerIndex,
    required String dcIp,
    required int dcId,
    required String savedAuthKey,
    required int apiId,
    required String apiHash,
  }) async {
    final initPort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();

    final isolate = await Isolate.spawn(
      uploadIsolateEntryPoint,
      IsolateInitMessage(
        sendPort: initPort.sendPort,
        workerIndex: workerIndex,
        dcIp: dcIp,
        dcId: dcId,
        savedAuthKey: savedAuthKey,
        apiId: apiId,
        apiHash: apiHash,
      ),
      debugName: 'ValtSky_UploadWorker_$workerIndex',
      errorsAreFatal: false,
    );

    isolate.addErrorListener(errorPort.sendPort);
    isolate.addOnExitListener(exitPort.sendPort);

    // Explicitly close the one-shot initPort to prevent Dart VM port registry leaks
    final commandPort = await initPort.first as SendPort;
    initPort.close();

    final eventPort = ReceivePort();
    commandPort.send(eventPort.sendPort);

    final client = IsolateUploadClient._(
      workerIndex,
      isolate,
      commandPort,
      eventPort,
      errorPort,
      exitPort,
    );
    client._listenEvents();
    return client;
  }

  void _listenEvents() {
    _eventPort.listen((message) {
      if (message is Map<String, dynamic>) {
        final type = message['type'] as String?;
        if (type == 'progress') {
          final sent = message['sent'] as int;
          final total = message['total'] as int;
          _currentProgressCallback?.call(sent, total);
        } else if (type == 'success') {
          final messageId = message['messageId'] as int;
          _currentJobCompleter?.complete(Success(messageId));
          _currentJobCompleter = null;
          _currentProgressCallback = null;
        } else if (type == 'telegram_error') {
          final code = message['code'] as int;
          final description = message['description'] as String;
          final retryAfter = message['retryAfter'] as int?;
          _currentJobCompleter?.complete(TelegramError(code, description, retryAfterSeconds: retryAfter));
          _currentJobCompleter = null;
          _currentProgressCallback = null;
        } else if (type == 'failure') {
          final error = message['error'] as String;
          _currentJobCompleter?.complete(Failure(error));
          _currentJobCompleter = null;
          _currentProgressCallback = null;
        }
      }
    });

    _errorPort.listen((error) {
      debugPrint('[IsolateUploadClient #$workerIndex] Uncaught isolate error: $error');
      if (_currentJobCompleter != null && !_currentJobCompleter!.isCompleted) {
        _currentJobCompleter!.complete(Failure('Isolate worker error: $error'));
        _currentJobCompleter = null;
        _currentProgressCallback = null;
      }
    });

    _exitPort.listen((_) {
      if (_currentJobCompleter != null && !_currentJobCompleter!.isCompleted) {
        _currentJobCompleter!.complete(Failure('Isolate worker terminated unexpectedly'));
        _currentJobCompleter = null;
        _currentProgressCallback = null;
      }
      _errorPort.close();
      _exitPort.close();
    });
  }

  Future<UploadResult> upload({
    required String filePath,
    required String channelId,
    required bool asDocument,
    String? caption,
    String? channelAccessHash,
    bool smoothMode = true,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_isDisposed) {
      return Failure('Cannot upload on disposed isolate client');
    }
    if (_currentJobCompleter != null && !_currentJobCompleter!.isCompleted) {
      throw StateError('Isolate worker $workerIndex is already running an upload');
    }

    final completer = Completer<UploadResult>();
    _currentJobCompleter = completer;
    _currentProgressCallback = onProgress;

    _commandPort.send({
      'command': 'upload',
      'filePath': filePath,
      'channelId': channelId,
      'channelAccessHash': channelAccessHash,
      'asDocument': asDocument,
      'caption': caption,
      'smoothMode': smoothMode,
    });

    return completer.future;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Fail any active job gracefully so caller does not hang
    if (_currentJobCompleter != null && !_currentJobCompleter!.isCompleted) {
      _currentJobCompleter!.complete(Failure('Upload cancelled: isolate worker disposed'));
      _currentJobCompleter = null;
    }
    _currentProgressCallback = null;

    try {
      _commandPort.send({'command': 'close'});
    } catch (_) {}

    _eventPort.close();
    _errorPort.close();
    _exitPort.close();

    // Allow the isolate event loop to process the close command before killing
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

/// Background isolate entry point. Runs MTProto encryption, socket transport,
/// and multi-socket parallel chunking independently from the Flutter main isolate.
void uploadIsolateEntryPoint(IsolateInitMessage init) async {
  final commandPort = ReceivePort();
  init.sendPort.send(commandPort.sendPort);

  SendPort? eventPort;
  final pool = <int, tg.Client>{};

  Future<tg.Client> getOrConnectClient(int socketIndex) async {
    if (pool.containsKey(socketIndex) && pool[socketIndex] != null) {
      return pool[socketIndex]!;
    }
    final authMap = jsonDecode(init.savedAuthKey) as Map<String, dynamic>;
    final authKey = tg.AuthorizationKey.fromJson(authMap);
    final socket = await TelegramTransport.connect(init.dcIp, 443);
    final obfuscation = tg.Obfuscation.random(false, init.dcId);
    final idGenerator = tg.MessageIdGenerator();
    await socket.send(obfuscation.preamble);
    final newClient = tg.Client(
      socket: socket,
      obfuscation: obfuscation,
      authorizationKey: authKey,
      idGenerator: idGenerator,
    );
    if (socketIndex == 0) {
      try {
        await newClient.initConnection<t.Config>(
          apiId: init.apiId,
          deviceModel: 'ValtSky Android Client',
          systemVersion: 'Android 14',
          appVersion: '2.1.0',
          systemLangCode: 'en',
          langPack: '',
          langCode: 'en',
          query: const t.HelpGetConfig(),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    pool[socketIndex] = newClient;
    return newClient;
  }

  void resetSocket(int socketIndex) {
    if (pool.containsKey(socketIndex) && pool[socketIndex] != null) {
      try {
        TelegramTransport.closeSocket(pool[socketIndex]!.socket);
      } catch (_) {}
      pool.remove(socketIndex);
    }
  }

  void resetAllSockets() {
    for (final client in pool.values) {
      try {
        TelegramTransport.closeSocket(client.socket);
      } catch (_) {}
    }
    pool.clear();
  }

  commandPort.listen((msg) async {
    if (msg is SendPort) {
      eventPort = msg;
      return;
    }
    if (msg is Map<String, dynamic>) {
      final command = msg['command'] as String?;
      if (command == 'close') {
        resetAllSockets();
        commandPort.close();
        Isolate.current.kill(priority: Isolate.immediate);
        return;
      }
      if (command == 'upload') {
        final filePath = msg['filePath'] as String;
        final channelId = msg['channelId'] as String;
        final channelAccessHash = msg['channelAccessHash'] as String?;
        final asDocument = msg['asDocument'] as bool;
        final caption = msg['caption'] as String?;

        try {
          try {
            await getOrConnectClient(0);
          } catch (e) {
            resetAllSockets();
            eventPort?.send({'type': 'failure', 'error': 'Failed to connect to Telegram DC: $e'});
            return;
          }

          final file = File(filePath);
          if (!await file.exists()) {
            eventPort?.send({'type': 'failure', 'error': 'File not found on storage'});
            return;
          }

          final cleanChannelId = channelId.startsWith('-100')
              ? channelId.substring(4)
              : (channelId.startsWith('-') ? channelId.substring(1) : channelId);
          final intId = int.tryParse(cleanChannelId);
          t.InputPeerBase? peer;

          if (channelAccessHash != null && intId != null) {
            final accessHash = int.tryParse(channelAccessHash);
            if (accessHash != null) {
              peer = t.InputPeerChannel(channelId: intId, accessHash: accessHash);
            }
          }

          if (peer == null && intId != null) {
            try {
              final client0 = pool[0] ?? await getOrConnectClient(0);
              final dialogsRes = await client0.messages.getDialogs(
                excludePinned: false,
                offsetDate: DateTime.fromMillisecondsSinceEpoch(0),
                offsetId: 0,
                offsetPeer: const t.InputPeerEmpty(),
                limit: 100,
                hash: 0,
              ).timeout(const Duration(seconds: 10));
              if (dialogsRes.result != null) {
                final d = dialogsRes.result!;
                List<t.ChatBase> chats = [];
                if (d is t.MessagesDialogs) chats = d.chats;
                if (d is t.MessagesDialogsSlice) chats = d.chats;
                for (final chat in chats) {
                  if (chat is t.Channel && chat.id == intId && chat.accessHash != null) {
                    peer = t.InputPeerChannel(channelId: chat.id, accessHash: chat.accessHash!);
                    break;
                  } else if (chat is t.Chat && chat.id == intId) {
                    peer = t.InputPeerChat(chatId: chat.id);
                    break;
                  }
                }
              }
            } catch (_) {}
          }

          if (peer == null) {
            eventPort?.send({'type': 'failure', 'error': 'Could not obtain channel access hash for $channelId'});
            return;
          }

          final fileSize = await file.length();
          final rawName = file.path.split('/').last;
          final fileName = FileSecurityGuard.sanitizeFileName(rawName);
          final mimeType = TelegramApi.getMimeType(file.path);

          final int chunkSize = (fileSize < 1024 * 1024) ? (256 * 1024) : (512 * 1024);
          final totalParts = (fileSize / chunkSize).ceil();
          final isBigFile = fileSize > 10 * 1024 * 1024;
          final fileId = (Random().nextInt(0x7fffffff) << 16) | Random().nextInt(0xffff);

          int bytesSent = 0;
          // Scale socket pool: 4 parallel TCP connections for large videos, 2 for multi-chunk photos, 1 for small files
          final int workerCount = totalParts <= 1
              ? 1
              : (isBigFile ? 4 : (totalParts <= 4 ? totalParts : 2));

          int nextPartIndex = 0;
          int? abortErrorCode;
          String? abortErrorMessage;
          DateTime lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);

          Future<void> isolateWorker(int workerIndex) async {
            // Reusable pre-allocated 512KB chunk buffer per worker (eliminates GC churn)
            final Uint8List workerChunkBuffer = Uint8List(chunkSize);
            RandomAccessFile? workerRaf;

            try {
              // Dedicated read-only file handle for this worker (eliminates disk lock contention)
              workerRaf = await file.open(mode: FileMode.read);
              tg.Client client = await getOrConnectClient(workerIndex);

              while (true) {
                if (abortErrorMessage != null) return;

                int part;
                int bytesRead;

                if (nextPartIndex >= totalParts || abortErrorMessage != null) {
                  return;
                }
                part = nextPartIndex++;

                final offset = part * chunkSize;
                final bytesToRead = (part == totalParts - 1) ? (fileSize - offset) : chunkSize;

                await workerRaf.setPosition(offset);
                bytesRead = await workerRaf.readInto(workerChunkBuffer, 0, bytesToRead);

                final buffer = (bytesRead == chunkSize)
                    ? workerChunkBuffer
                    : Uint8List.sublistView(workerChunkBuffer, 0, bytesRead);

                t.Result<t.Boolean>? partResult;
                int retries = 0;
                const maxPartRetries = 3;

                while (retries <= maxPartRetries) {
                  if (abortErrorMessage != null) return;
                  try {
                    if (isBigFile) {
                      partResult = await client.upload.saveBigFilePart(
                        fileId: fileId,
                        filePart: part,
                        fileTotalParts: totalParts,
                        bytes: buffer,
                      ).timeout(const Duration(seconds: 40));
                    } else {
                      partResult = await client.upload.saveFilePart(
                        fileId: fileId,
                        filePart: part,
                        bytes: buffer,
                      ).timeout(const Duration(seconds: 40));
                    }

                    if (partResult.error == null) break;

                    final errMsg = partResult.error!.errorMessage;
                    if (errMsg.contains('FLOOD_WAIT') ||
                        errMsg.contains('AUTH_KEY') ||
                        errMsg.contains('SESSION_REVOKED') ||
                        errMsg.contains('USER_DEACTIVATED')) {
                      abortErrorCode = partResult.error!.errorCode;
                      abortErrorMessage = errMsg;
                      return;
                    }
                    retries++;
                    if (retries <= maxPartRetries) {
                      await Future.delayed(Duration(milliseconds: 150 * retries));
                    }
                  } catch (err) {
                    retries++;
                    if (retries > maxPartRetries) {
                      abortErrorCode = -1;
                      abortErrorMessage = err.toString();
                      resetSocket(workerIndex);
                      return;
                    }
                    resetSocket(workerIndex);
                    try {
                      client = await getOrConnectClient(workerIndex);
                    } catch (_) {}
                    await Future.delayed(Duration(milliseconds: 150 * retries));
                  }
                }

                if (partResult == null || partResult.error != null) {
                  abortErrorCode = partResult?.error?.errorCode ?? -1;
                  abortErrorMessage = partResult?.error?.errorMessage ?? 'Unknown upload error';
                  return;
                }

                bytesSent += buffer.length;
                final now = DateTime.now();
                if (now.difference(lastProgressEmit).inMilliseconds >= 300 || bytesSent >= fileSize) {
                  lastProgressEmit = now;
                  eventPort?.send({'type': 'progress', 'sent': bytesSent, 'total': fileSize});
                }
              }
            } catch (workerErr) {
              if (abortErrorMessage == null) {
                abortErrorCode = -1;
                abortErrorMessage = workerErr.toString();
              }
            } finally {
              try {
                await workerRaf?.close();
              } catch (_) {}
            }
          }

          final workers = List.generate(workerCount, (i) => isolateWorker(i));
          await Future.wait(workers);

          if (abortErrorMessage != null) {
            resetAllSockets();
            eventPort?.send({
              'type': 'telegram_error',
              'code': abortErrorCode ?? -1,
              'description': abortErrorMessage!,
            });
            return;
          }

          final t.InputFileBase inputFile = isBigFile
              ? t.InputFileBig(id: fileId, parts: totalParts, name: fileName)
              : t.InputFile(id: fileId, parts: totalParts, name: fileName, md5Checksum: '');

          final isVideoFile = mimeType.startsWith('video/');
          final inputMedia = t.InputMediaUploadedDocument(
            nosoundVideo: false,
            forceFile: asDocument,
            spoiler: false,
            file: inputFile,
            mimeType: mimeType,
            attributes: [
              t.DocumentAttributeFilename(fileName: fileName),
              if (isVideoFile)
                const t.DocumentAttributeVideo(
                  roundMessage: false,
                  supportsStreaming: true,
                  nosound: false,
                  duration: 0.0,
                  w: 0,
                  h: 0,
                ),
            ],
          );

          final randomId = Random().nextInt(0x7fffffff);
          final mediaClient = pool[0] ?? await getOrConnectClient(0);
          var sendResult = await mediaClient.messages.sendMedia(
            silent: false,
            background: false,
            clearDraft: false,
            noforwards: false,
            updateStickersetsOrder: false,
            invertMedia: false,
            allowPaidFloodskip: false,
            peer: peer,
            media: inputMedia,
            message: caption ?? '',
            randomId: randomId,
          ).timeout(const Duration(seconds: 45));

          if (sendResult.error != null) {
            resetAllSockets();
            eventPort?.send({
              'type': 'telegram_error',
              'code': sendResult.error!.errorCode,
              'description': sendResult.error!.errorMessage,
            });
            return;
          }

          int msgId = DateTime.now().millisecondsSinceEpoch;
          final updates = sendResult.result;
          if (updates is t.Updates) {
            for (final upd in updates.updates) {
              if (upd is t.UpdateNewChannelMessage && upd.message is t.Message) {
                msgId = (upd.message as t.Message).id;
                break;
              } else if (upd is t.UpdateNewMessage && upd.message is t.Message) {
                msgId = (upd.message as t.Message).id;
                break;
              }
            }
          }

          eventPort?.send({
            'type': 'success',
            'messageId': msgId,
          });
        } catch (e) {
          resetAllSockets();
          eventPort?.send({'type': 'failure', 'error': e.toString()});
        }
      }
    }
  });
}
