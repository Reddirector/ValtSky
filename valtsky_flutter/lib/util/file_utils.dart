import 'dart:io';
import 'package:crypto/crypto.dart';

class FileUtils {
  static Future<String?> getFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (e) {
      return null;
    }
  }
}
