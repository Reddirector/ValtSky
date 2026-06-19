import 'dart:io';
import 'package:dio/dio.dart';

abstract class UploadResult {
  bool get isSuccess;
}

class Success extends UploadResult {
  final int telegramMessageId;
  Success(this.telegramMessageId);
  @override
  bool get isSuccess => true;
}

class Failure extends UploadResult {
  final String message;
  Failure(this.message);
  @override
  bool get isSuccess => false;
}

class TelegramError extends UploadResult {
  final int code;
  final String description;
  final int? retryAfterSeconds;
  TelegramError(this.code, this.description, {this.retryAfterSeconds});
  @override
  bool get isSuccess => false;
}

class TelegramApi {
  static final Dio _dio = Dio();

  static Future<UploadResult> sendMedia(
    String botToken,
    String channelId,
    File file,
    bool asDocument,
    String? caption,
  ) async {
    final mimeType = _getMimeType(file.path);
    final isVideo = mimeType.startsWith('video');
    final isImage = mimeType.startsWith('image');

    String method;
    String field;

    if (asDocument) {
      method = 'sendDocument';
      field = 'document';
    } else if (isVideo) {
      method = 'sendVideo';
      field = 'video';
    } else if (isImage) {
      method = 'sendPhoto';
      field = 'photo';
    } else {
      method = 'sendDocument';
      field = 'document';
    }

    try {
      final formData = FormData.fromMap({
        'chat_id': channelId,
        field: await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
        if (caption != null) 'caption': caption,
      });

      final response = await _dio.post('https://api.telegram.org/bot\$botToken/\$method', data: formData);

      if (response.statusCode == 200) {
        final result = response.data['result'];
        return Success(result['message_id']);
      } else {
        return TelegramError(
          response.statusCode ?? -1,
          response.data['description'] ?? 'Unknown error',
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        return TelegramError(
          e.response!.statusCode ?? -1,
          data['description'] ?? e.message ?? 'Unknown error',
          retryAfterSeconds: data['parameters']?['retry_after'],
        );
      }
      return Failure(e.message ?? 'Network error');
    } catch (e) {
      return Failure(e.toString());
    }
  }

  static Future<String?> getBotInfo(String botToken) async {
    try {
      final response = await _dio.get('https://api.telegram.org/bot\$botToken/getMe');
      if (response.statusCode == 200) {
        final result = response.data['result'];
        return result['first_name'] ?? result['username'];
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getChannelInfo(String botToken, String channelId) async {
    try {
      final response = await _dio.get('https://api.telegram.org/bot\$botToken/getChat', queryParameters: {'chat_id': channelId});
      if (response.statusCode == 200) {
        final result = response.data['result'];
        return result['title'] ?? result['username'];
      }
    } catch (_) {}
    return null;
  }

  static String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
