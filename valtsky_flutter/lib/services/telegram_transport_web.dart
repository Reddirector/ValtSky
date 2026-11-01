import 'dart:async';
import 'package:tg/tg.dart' as tg;

class TelegramTransport {
  static Future<tg.SocketAbstraction> connect(String ip, int port) async {
    throw UnsupportedError(
      'Raw TCP sockets are not supported in standard web browsers. '
      'Please run ValtSky on an Android device or desktop platform for direct MTProto connections.',
    );
  }
}
