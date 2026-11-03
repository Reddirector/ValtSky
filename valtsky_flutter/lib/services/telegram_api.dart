import 'dart:io';
import 'package:dio/dio.dart';
import '../data/prefs.dart';
import '../util/file_security_guard.dart';

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
  // High-performance HTTP client with persistent connection pool & Keep-Alive
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=60, max=100',
      },
    ),
  );

  static String get _baseUrl {
    final configured = Prefs.apiBaseUrl;
    final validation = FileSecurityGuard.validateApiUrl(configured);
    if (!validation.isValid) {
      // Security fallback to official secure endpoint if invalid/SSRF attempted
      return 'https://api.telegram.org';
    }
    return configured;
  }

  static Future<UploadResult> sendMedia(
    String botToken,
    String channelId,
    File file,
    bool asDocument,
    String? caption, {
    String? overrideFileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final mimeType = getMimeType(file.path);
    final isVideo = mimeType.startsWith('video');
    final isImage = mimeType.startsWith('image');
    final rawName = overrideFileName ?? file.path.split('/').last;
    final fileName = FileSecurityGuard.sanitizeFileName(rawName);

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
        field: await MultipartFile.fromFile(file.path, filename: fileName),
        'caption': ?caption,
      });

      final response = await _dio.post(
        '$_baseUrl/bot$botToken/$method',
        data: formData,
        onSendProgress: onProgress,
      );

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

  /// High-speed in-memory chunk upload: streams raw bytes directly without disk I/O bottlenecks
  static Future<UploadResult> sendBytes(
    String botToken,
    String channelId,
    List<int> bytes,
    String fileName,
    bool asDocument,
    String? caption, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final safeFileName = FileSecurityGuard.sanitizeFileName(fileName);
    final mimeType = getMimeType(safeFileName);
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
        field: MultipartFile.fromBytes(bytes, filename: safeFileName),
        'caption': ?caption,
      });

      final response = await _dio.post(
        '$_baseUrl/bot$botToken/$method',
        data: formData,
        onSendProgress: onProgress,
      );

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

  static Future<int?> sendMessage(
    String botToken,
    String channelId,
    String text,
  ) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/bot$botToken/sendMessage',
        data: {
          'chat_id': channelId,
          'text': text,
          'parse_mode': 'Markdown',
        },
      );
      if (response.statusCode == 200) {
        return response.data['result']?['message_id'];
      }
    } catch (_) {
      // Fallback: If markdown formatting causes parser rejection, resend plain text to prevent data loss
      try {
        final fallbackResponse = await _dio.post(
          '$_baseUrl/bot$botToken/sendMessage',
          data: {
            'chat_id': channelId,
            'text': text,
          },
        );
        if (fallbackResponse.statusCode == 200) {
          return fallbackResponse.data['result']?['message_id'];
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<String?> getBotInfo(String botToken) async {
    try {
      final response = await _dio.get('$_baseUrl/bot$botToken/getMe');
      if (response.statusCode == 200) {
        final result = response.data['result'];
        return result['first_name'] ?? result['username'];
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getChannelInfo(String botToken, String channelId) async {
    try {
      final response = await _dio.get('$_baseUrl/bot$botToken/getChat', queryParameters: {'chat_id': channelId});
      if (response.statusCode == 200) {
        final result = response.data['result'];
        return result['title'] ?? result['username'];
      }
    } catch (_) {}
    return null;
  }

  static String getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream';
    }
  }
}
