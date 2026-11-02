import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tg/tg.dart' as tg;

class _IoSocket extends tg.SocketAbstraction {
  _IoSocket(this.socket) : receiver = socket.asBroadcastStream();
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

class TelegramTransport {
  static Future<tg.SocketAbstraction> connect(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 8));
      return _IoSocket(socket);
    } catch (e) {
      if (port == 443) {
        debugPrint('[TelegramTransport] Port 443 failed ($e), retrying on port 80...');
        final socket = await Socket.connect(ip, 80, timeout: const Duration(seconds: 8));
        return _IoSocket(socket);
      }
      rethrow;
    }
  }
}
