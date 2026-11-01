import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 10));
    return _IoSocket(socket);
  }
}
