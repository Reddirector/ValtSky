import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/prefs.dart';
import 'telegram_api.dart';

enum AuthStep {
  enterPhone,
  enterCode,
  enterPassword,
  provisioning,
  completed,
  error,
}

class AuthState {
  final AuthStep step;
  final String? phoneNumber;
  final String? phoneCodeHash;
  final String? errorMessage;
  final String? provisionedChannelName;
  final String? provisionedChannelId;
  final String? userName;
  final String? userHandle;
  final String? userId;
  final bool isPremium;
  final bool isLoading;
  final String? deliveryDescription;
  final int codeLength;
  final int timeoutSeconds;

  const AuthState({
    required this.step,
    this.phoneNumber,
    this.phoneCodeHash,
    this.errorMessage,
    this.provisionedChannelName,
    this.provisionedChannelId,
    this.userName,
    this.userHandle,
    this.userId,
    this.isPremium = false,
    this.isLoading = false,
    this.deliveryDescription,
    this.codeLength = 5,
    this.timeoutSeconds = 60,
  });

  factory AuthState.initial() => const AuthState(step: AuthStep.enterPhone);

  AuthState copyWith({
    AuthStep? step,
    String? phoneNumber,
    String? phoneCodeHash,
    String? errorMessage,
    String? provisionedChannelName,
    String? provisionedChannelId,
    String? userName,
    String? userHandle,
    String? userId,
    bool? isPremium,
    bool? isLoading,
    String? deliveryDescription,
    int? codeLength,
    int? timeoutSeconds,
  }) {
    return AuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCodeHash: phoneCodeHash ?? this.phoneCodeHash,
      errorMessage: errorMessage,
      provisionedChannelName: provisionedChannelName ?? this.provisionedChannelName,
      provisionedChannelId: provisionedChannelId ?? this.provisionedChannelId,
      userName: userName ?? this.userName,
      userHandle: userHandle ?? this.userHandle,
      userId: userId ?? this.userId,
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      deliveryDescription: deliveryDescription ?? this.deliveryDescription,
      codeLength: codeLength ?? this.codeLength,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }
}

/// Telegram Web Authentication Service.
/// Communicates with the local ValtSky MTProto Bridge (http://localhost:8088)
/// to bypass browser raw TCP socket limitations and execute real Telegram MTProto authentication.
class TelegramAuthService {
  static final TelegramAuthService instance = TelegramAuthService._();
  TelegramAuthService._();

  final ValueNotifier<AuthState> stateNotifier = ValueNotifier<AuthState>(AuthState.initial());
  AuthState get currentState => stateNotifier.value;

  static String get _bridgeUrl {
    final host = Uri.base.host;
    if (host.isNotEmpty) {
      return 'http://$host:8088';
    }
    return 'http://localhost:8088';
  }

  Dio get _dio => Dio(BaseOptions(
    baseUrl: _bridgeUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
  ));

  static bool isValidPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(clean);
  }

  Future<bool> sendVerificationCode(String rawPhoneNumber) async {
    final cleanPhone = rawPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!isValidPhoneNumber(cleanPhone)) {
      stateNotifier.value = currentState.copyWith(
        step: AuthStep.enterPhone,
        errorMessage: 'Please enter a valid international phone number with country code (e.g. +1 555 123 4567 or +91 98765 43210)',
        isLoading: false,
      );
      return false;
    }

    stateNotifier.value = currentState.copyWith(
      phoneNumber: cleanPhone,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final response = await _dio.post(
        '/api/send_code',
        data: {'phone': cleanPhone},
      );

      final data = response.data is Map ? response.data as Map<String, dynamic> : {};
      if (data['ok'] == true) {
        final hash = data['phoneCodeHash'] as String? ?? '';
        stateNotifier.value = currentState.copyWith(
          step: AuthStep.enterCode,
          phoneCodeHash: hash,
          isLoading: false,
        );
        return true;
      } else {
        final err = data['friendlyError'] ?? data['error'] ?? 'Failed to send verification code';
        stateNotifier.value = currentState.copyWith(
          step: AuthStep.enterPhone,
          errorMessage: err.toString(),
          isLoading: false,
        );
        return false;
      }
    } on DioException catch (e) {
      String message = 'Cannot reach Telegram MTProto Bridge. Ensure bridge is running on port 8088.';
      if (e.response?.data != null && e.response!.data is Map) {
        final resp = e.response!.data as Map<String, dynamic>;
        message = resp['friendlyError']?.toString() ?? resp['error']?.toString() ?? message;
      }
      stateNotifier.value = currentState.copyWith(
        step: AuthStep.enterPhone,
        errorMessage: message,
        isLoading: false,
      );
      return false;
    } catch (e) {
      stateNotifier.value = currentState.copyWith(
        step: AuthStep.enterPhone,
        errorMessage: 'Connection error: ${e.toString()}',
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> resendCode() async {
    final phone = currentState.phoneNumber;
    final hash = currentState.phoneCodeHash;
    if (phone == null || hash == null) {
      stateNotifier.value = currentState.copyWith(
        errorMessage: 'Unable to resend: missing phone number or session hash',
      );
      return false;
    }

    stateNotifier.value = currentState.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final res = await _dio.post(
        '/api/resend_code',
        data: {'phone_number': phone, 'phone_code_hash': hash},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = res.data as Map<String, dynamic>;
      if (data['ok'] == true) {
        stateNotifier.value = currentState.copyWith(
          step: AuthStep.enterCode,
          phoneCodeHash: data['phoneCodeHash'] as String,
          timeoutSeconds: data['timeout'] as int? ?? 60,
          deliveryDescription: 'A new verification code was resent via Telegram / SMS.',
          isLoading: false,
        );
        return true;
      } else {
        final err = data['friendlyError'] ?? data['error'] ?? 'Failed to resend code';
        stateNotifier.value = currentState.copyWith(
          errorMessage: err.toString(),
          isLoading: false,
        );
        return false;
      }
    } on DioException catch (e) {
      String message = 'Cannot reach Telegram MTProto Bridge. Ensure bridge is running on port 8088.';
      if (e.response?.data != null && e.response!.data is Map) {
        final resp = e.response!.data as Map<String, dynamic>;
        message = resp['friendlyError']?.toString() ?? resp['error']?.toString() ?? message;
      }
      stateNotifier.value = currentState.copyWith(
        errorMessage: message,
        isLoading: false,
      );
      return false;
    } catch (e) {
      stateNotifier.value = currentState.copyWith(
        errorMessage: 'Connection error: ${e.toString()}',
        isLoading: false,
      );
      return false;
    }
  }

  Future<bool> verifyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length < 5) {
      stateNotifier.value = currentState.copyWith(
        errorMessage: 'Please enter the complete 5-digit verification code sent in Telegram',
      );
      return false;
    }

    stateNotifier.value = currentState.copyWith(
      step: AuthStep.provisioning,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final response = await _dio.post(
        '/api/verify_code',
        data: {'code': trimmed},
      );

      final data = response.data is Map ? response.data as Map<String, dynamic> : {};
      if (data['ok'] == true) {
        final channelId = data['channelId'] as String? ?? '-1002891238921';
        final channelName = data['channelName'] as String? ?? 'ValtSky Private Vault';
        final userId = data['userId'] as String? ?? '';
        final userName = data['userName'] as String? ?? '';
        final userHandle = data['userHandle'] as String? ?? '';
        final isPremium = data['isPremium'] == true;
        final phone = data['phoneNumber'] as String?;

        return _completeProvisioning(
          channelId,
          channelName,
          userId: userId,
          userName: userName,
          userHandle: userHandle,
          isPremium: isPremium,
          phoneNumber: phone,
        );
      } else {
        final err = data['friendlyError'] ?? data['error'] ?? 'Verification failed';
        stateNotifier.value = currentState.copyWith(
          step: AuthStep.enterCode,
          errorMessage: err.toString(),
          isLoading: false,
        );
        return false;
      }
    } on DioException catch (e) {
      String message = 'Verification failed. Bridge connection error.';
      if (e.response?.data != null && e.response!.data is Map) {
        final resp = e.response!.data as Map<String, dynamic>;
        message = resp['friendlyError']?.toString() ?? resp['error']?.toString() ?? message;
      }
      stateNotifier.value = currentState.copyWith(
        step: AuthStep.enterCode,
        errorMessage: message,
        isLoading: false,
      );
      return false;
    } catch (e) {
      stateNotifier.value = currentState.copyWith(
        step: AuthStep.enterCode,
        errorMessage: 'Verification error: ${e.toString()}',
        isLoading: false,
      );
      return false;
    }
  }

  bool _completeProvisioning(
    String channelId,
    String channelName, {
    String? userId,
    String? userName,
    String? userHandle,
    bool? isPremium,
    String? phoneNumber,
  }) {
    Prefs.authMethod = 'phone';
    Prefs.userPhoneNumber = phoneNumber ?? currentState.phoneNumber ?? '';
    Prefs.channelId = channelId;
    Prefs.channelName = channelName;
    Prefs.botName = 'ValtSkySync';
    if (userId != null && userId.isNotEmpty) Prefs.telegramUserId = userId;
    if (userName != null && userName.isNotEmpty) Prefs.telegramUserName = userName;
    if (userHandle != null && userHandle.isNotEmpty) Prefs.telegramUserHandle = userHandle;
    if (isPremium != null) Prefs.telegramIsPremium = isPremium;

    if (Prefs.botToken.isEmpty) {
      Prefs.botToken = 'mtproto_session_active';
    }
    Prefs.monitoringEnabled = true;

    stateNotifier.value = currentState.copyWith(
      step: AuthStep.completed,
      provisionedChannelId: channelId,
      provisionedChannelName: channelName,
      userId: userId,
      userName: userName,
      userHandle: userHandle,
      isPremium: isPremium,
      isLoading: false,
    );

    return true;
  }

  Future<UploadResult> uploadMedia({
    required File file,
    required String channelId,
    required bool asDocument,
    String? caption,
    void Function(int sent, int total)? onProgress,
    int workerIndex = 0,
  }) async {
    return Failure('Direct MTProto upload from web requires desktop/mobile app or bridge');
  }

  Future<UploadResult> sendMessage({
    required String channelId,
    required String text,
  }) async {
    return Failure('Direct MTProto message from web requires desktop/mobile app or bridge');
  }

  void invalidateClient([int workerIndex = 0]) {}

  void resetClientPool() {}

  void reset() {
    stateNotifier.value = AuthState.initial();
  }
}
