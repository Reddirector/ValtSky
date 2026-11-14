import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NetworkTypeChoice { wifi, mobile, both }
enum ThemeChoice { light, dark }

class Prefs {
  static const String keyBotToken = 'bot_token';
  static const String keyChannelId = 'channel_id';
  static const String keyEnabled = 'monitoring_enabled';
  static const String keyLastSynced = 'last_synced_ts';
  static const String keyOriginalQuality = 'use_original_quality';
  static const String keyConfigLocked = 'config_locked';
  static const String keyNetworkType = 'network_type';
  static const String keyBotName = 'bot_name';
  static const String keyChannelName = 'channel_name';
  static const String keySelectedTheme = 'selected_theme';
  static const String keyUploadPaused = 'upload_paused';
  static const String keyApiBaseUrl = 'api_base_url';
  static const String keyEnableChunking = 'enable_chunking';
  static const String keyMaxChunkSizeMb = 'max_chunk_size_mb';
  static const String keyAuthMethod = 'auth_method'; // 'phone' or 'bot'
  static const String keyUserPhoneNumber = 'user_phone_number';
  static const String keyTelegramUserId = 'telegram_user_id';
  static const String keyTelegramUserName = 'telegram_user_name';
  static const String keyTelegramUserHandle = 'telegram_user_handle';
  static const String keyTelegramIsPremium = 'telegram_is_premium';
  static const String keyTelegramAuthKey = 'telegram_auth_key';
  static const String keyTelegramDcId = 'telegram_dc_id';
  static const String keyTelegramDcIp = 'telegram_dc_ip';
  static const String keyTutorialDismissed = 'tutorial_dismissed';
  static const String keyChannelAccessHash = 'channel_access_hash';
  static const String keyPermissionsRequested = 'permissions_requested_v1';
  static const String keyVaultPinEnabled = 'vault_pin_enabled';
  static const String keyVaultPin = 'vault_pin';
  static const String keySmoothUploadMode = 'smooth_upload_mode';
  static const String keyCustomVaultName = 'custom_vault_name';
  static const String keyScheduledBackupEnabled = 'scheduled_backup_enabled';
  static const String keyScheduledBackupHour = 'scheduled_backup_hour';
  static const String keyScheduledBackupMinute = 'scheduled_backup_minute';
  static const String keyScheduledBackupRepeatDaily = 'scheduled_backup_repeat_daily';

  // Session persistence keys — survive app kill/restart
  static const String keySessionTotal = 'session_total';
  static const String keySessionSynced = 'session_synced';
  static const String keySessionComplete = 'session_complete';
  static const String keySessionProgress = 'session_progress';
  static const String keyLastMainHeartbeat = 'last_main_heartbeat';
  static const String keyBackgroundSyncActive = 'background_sync_active';

  // Fast-cache snapshot counters for instant 0ms cold-start render
  static const String keyLastTotal = 'last_total_count';
  static const String keyLastSyncedCount = 'last_synced_count';
  static const String keyLastInQueue = 'last_in_queue_count';
  static const String keyLastFailed = 'last_failed_count';
  static const String keyLastUploading = 'last_uploading_count';

  static final ValueNotifier<bool> smoothUploadModeNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> scheduledBackupNotifier = ValueNotifier<bool>(false);

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    smoothUploadModeNotifier.value = smoothUploadMode;
    scheduledBackupNotifier.value = scheduledBackupEnabled;
  }

  static Future<void> reload() async {
    await _prefs?.reload();
  }

  static String get authMethod => _prefs?.getString(keyAuthMethod) ?? 'phone';
  static set authMethod(String value) => _prefs?.setString(keyAuthMethod, value);

  static String get userPhoneNumber => _prefs?.getString(keyUserPhoneNumber) ?? '';
  static set userPhoneNumber(String value) => _prefs?.setString(keyUserPhoneNumber, value);

  static String get telegramUserId => _prefs?.getString(keyTelegramUserId) ?? '';
  static set telegramUserId(String value) => _prefs?.setString(keyTelegramUserId, value);

  static String get telegramUserName => _prefs?.getString(keyTelegramUserName) ?? '';
  static set telegramUserName(String value) => _prefs?.setString(keyTelegramUserName, value);

  static String get telegramUserHandle => _prefs?.getString(keyTelegramUserHandle) ?? '';
  static set telegramUserHandle(String value) => _prefs?.setString(keyTelegramUserHandle, value);

  static bool get telegramIsPremium => _prefs?.getBool(keyTelegramIsPremium) ?? false;
  static set telegramIsPremium(bool value) => _prefs?.setBool(keyTelegramIsPremium, value);

  static String? get telegramAuthKey => _prefs?.getString(keyTelegramAuthKey);
  static set telegramAuthKey(String? value) {
    if (value == null) {
      _prefs?.remove(keyTelegramAuthKey);
    } else {
      _prefs?.setString(keyTelegramAuthKey, value);
    }
  }

  static int get telegramDcId => _prefs?.getInt(keyTelegramDcId) ?? 1;
  static set telegramDcId(int value) => _prefs?.setInt(keyTelegramDcId, value);

  static String? get telegramDcIp => _prefs?.getString(keyTelegramDcIp);
  static set telegramDcIp(String? value) {
    if (value == null) {
      _prefs?.remove(keyTelegramDcIp);
    } else {
      _prefs?.setString(keyTelegramDcIp, value);
    }
  }

  static String? get channelAccessHash => _prefs?.getString(keyChannelAccessHash);
  static set channelAccessHash(String? value) {
    if (value == null) {
      _prefs?.remove(keyChannelAccessHash);
    } else {
      _prefs?.setString(keyChannelAccessHash, value);
    }
  }

  static const String _pinSalt = 'valtsky_secure_vault_salt_v1';

  static String _hashPin(String rawPin) {
    if (rawPin.isEmpty) return '';
    final bytes = utf8.encode('$_pinSalt:$rawPin');
    return sha256.convert(bytes).toString();
  }

  static bool get vaultPinEnabled => _prefs?.getBool(keyVaultPinEnabled) ?? false;
  static set vaultPinEnabled(bool value) => _prefs?.setBool(keyVaultPinEnabled, value);

  static void setVaultPin(String rawPin) {
    if (rawPin.isEmpty) {
      _prefs?.remove(keyVaultPin);
    } else {
      _prefs?.setString(keyVaultPin, _hashPin(rawPin));
    }
  }

  static bool verifyVaultPin(String inputPin) {
    final storedHash = _prefs?.getString(keyVaultPin) ?? '';
    if (storedHash.isEmpty) return true;
    return storedHash == _hashPin(inputPin);
  }

  static bool get hasVaultPin => (_prefs?.getString(keyVaultPin) ?? '').isNotEmpty;

  static String get vaultPin => _prefs?.getString(keyVaultPin) ?? '';
  static set vaultPin(String value) => setVaultPin(value);

  static Future<void> disconnectTelegram() async {
    await _prefs?.remove(keyUserPhoneNumber);
    await _prefs?.remove(keyTelegramUserId);
    await _prefs?.remove(keyTelegramUserName);
    await _prefs?.remove(keyTelegramUserHandle);
    await _prefs?.remove(keyTelegramIsPremium);
    await _prefs?.remove(keyTelegramAuthKey);
    await _prefs?.remove(keyTelegramDcId);
    await _prefs?.remove(keyTelegramDcIp);
    await _prefs?.remove(keyChannelAccessHash);
    await _prefs?.remove(keyChannelId);
    await _prefs?.remove(keyChannelName);
    await _prefs?.remove(keyBotToken);
    await _prefs?.remove(keyBotName);
    await _prefs?.remove(keyEnabled);
    await _prefs?.remove(keyLastSynced);
    await _prefs?.remove(keyUploadPaused);
    await _prefs?.remove(keyLastTotal);
    await _prefs?.remove(keyLastSyncedCount);
    await _prefs?.remove(keyLastInQueue);
    await _prefs?.remove(keyLastFailed);
    await _prefs?.remove(keyLastUploading);
  }

  static String get botToken => _prefs?.getString(keyBotToken) ?? '';
  static set botToken(String value) => _prefs?.setString(keyBotToken, value.trim());

  static String get channelId => _prefs?.getString(keyChannelId) ?? '';
  static set channelId(String value) => _prefs?.setString(keyChannelId, value.trim());

  static bool get monitoringEnabled => _prefs?.getBool(keyEnabled) ?? false;
  static set monitoringEnabled(bool value) => _prefs?.setBool(keyEnabled, value);

  static bool get tutorialDismissed => _prefs?.getBool(keyTutorialDismissed) ?? false;
  static set tutorialDismissed(bool value) => _prefs?.setBool(keyTutorialDismissed, value);

  static bool get permissionsRequested => _prefs?.getBool(keyPermissionsRequested) ?? false;
  static set permissionsRequested(bool value) => _prefs?.setBool(keyPermissionsRequested, value);

  static int get lastSyncedTs => _prefs?.getInt(keyLastSynced) ?? 0;
  static set lastSyncedTs(int value) => _prefs?.setInt(keyLastSynced, value);

  static bool get useOriginalQuality => _prefs?.getBool(keyOriginalQuality) ?? true;
  static set useOriginalQuality(bool value) => _prefs?.setBool(keyOriginalQuality, value);

  static bool get configLocked => _prefs?.getBool(keyConfigLocked) ?? false;
  static set configLocked(bool value) => _prefs?.setBool(keyConfigLocked, value);

  static NetworkTypeChoice get uploadNetworkType {
    final val = _prefs?.getString(keyNetworkType) ?? 'BOTH';
    return NetworkTypeChoice.values.firstWhere(
      (e) => e.name.toUpperCase() == val.toUpperCase(),
      orElse: () => NetworkTypeChoice.both,
    );
  }
  static set uploadNetworkType(NetworkTypeChoice value) => _prefs?.setString(keyNetworkType, value.name.toUpperCase());

  static String get botName => _prefs?.getString(keyBotName) ?? '';
  static set botName(String value) => _prefs?.setString(keyBotName, value);

  static String get channelName => _prefs?.getString(keyChannelName) ?? '';
  static set channelName(String value) => _prefs?.setString(keyChannelName, value);

  static String get customVaultName => _prefs?.getString(keyCustomVaultName) ?? '';
  static set customVaultName(String value) => _prefs?.setString(keyCustomVaultName, value);

  static String get effectiveVaultName {
    if (channelName.isNotEmpty) return channelName;
    if (customVaultName.isNotEmpty) return customVaultName;
    final name = telegramUserName.isNotEmpty ? telegramUserName : telegramUserHandle;
    if (name.isNotEmpty) return 'VaultSky Vault ($name)';
    return 'VaultSky Vault';
  }

  static ThemeChoice get selectedTheme {
    final val = _prefs?.getString(keySelectedTheme) ?? 'LIGHT';
    return ThemeChoice.values.firstWhere(
      (e) => e.name.toUpperCase() == val.toUpperCase(),
      orElse: () => ThemeChoice.light,
    );
  }
  static set selectedTheme(ThemeChoice value) => _prefs?.setString(keySelectedTheme, value.name.toUpperCase());

  static bool get uploadPaused => _prefs?.getBool(keyUploadPaused) ?? false;
  static set uploadPaused(bool value) => _prefs?.setBool(keyUploadPaused, value);

  static String get apiBaseUrl => _prefs?.getString(keyApiBaseUrl) ?? 'https://api.telegram.org';
  static set apiBaseUrl(String value) => _prefs?.setString(keyApiBaseUrl, value.trim().replaceAll(RegExp(r'/+$'), ''));

  static bool get enableChunking => _prefs?.getBool(keyEnableChunking) ?? true;
  static set enableChunking(bool value) => _prefs?.setBool(keyEnableChunking, value);

  static int get maxChunkSizeMb => _prefs?.getInt(keyMaxChunkSizeMb) ?? 48;
  static set maxChunkSizeMb(int value) => _prefs?.setInt(keyMaxChunkSizeMb, value);

  static bool isConfigured() {
    if (channelId.isEmpty) return false;
    if (botToken.contains(':')) return true;
    if (authMethod == 'phone') {
      return (telegramAuthKey != null && telegramAuthKey!.isNotEmpty) ||
          userPhoneNumber.isNotEmpty;
    }
    return botToken.isNotEmpty;
  }

  static bool get smoothUploadMode => _prefs?.getBool(keySmoothUploadMode) ?? true;
  static set smoothUploadMode(bool value) {
    _prefs?.setBool(keySmoothUploadMode, value);
    smoothUploadModeNotifier.value = value;
  }

  static bool get scheduledBackupEnabled => _prefs?.getBool(keyScheduledBackupEnabled) ?? false;
  static set scheduledBackupEnabled(bool value) {
    _prefs?.setBool(keyScheduledBackupEnabled, value);
    scheduledBackupNotifier.value = value;
  }

  static int get scheduledBackupHour => _prefs?.getInt(keyScheduledBackupHour) ?? 2; // Default 2:00 AM
  static set scheduledBackupHour(int value) => _prefs?.setInt(keyScheduledBackupHour, value);

  static int get scheduledBackupMinute => _prefs?.getInt(keyScheduledBackupMinute) ?? 0;
  static set scheduledBackupMinute(int value) => _prefs?.setInt(keyScheduledBackupMinute, value);

  static bool get scheduledBackupRepeatDaily => _prefs?.getBool(keyScheduledBackupRepeatDaily) ?? true;
  static set scheduledBackupRepeatDaily(bool value) => _prefs?.setBool(keyScheduledBackupRepeatDaily, value);

  // ── Session Persistence (survives app kill/restart) ──────────────────────
  static int get sessionTotal => _prefs?.getInt(keySessionTotal) ?? 0;
  static set sessionTotal(int value) => _prefs?.setInt(keySessionTotal, value);

  static int get sessionSynced => _prefs?.getInt(keySessionSynced) ?? 0;
  static set sessionSynced(int value) => _prefs?.setInt(keySessionSynced, value);

  static bool get sessionComplete => _prefs?.getBool(keySessionComplete) ?? false;
  static set sessionComplete(bool value) => _prefs?.setBool(keySessionComplete, value);

  static double get sessionProgress => _prefs?.getDouble(keySessionProgress) ?? 0.0;
  static set sessionProgress(double value) => _prefs?.setDouble(keySessionProgress, value);

  static int get lastMainHeartbeat => _prefs?.getInt(keyLastMainHeartbeat) ?? 0;
  static set lastMainHeartbeat(int value) => _prefs?.setInt(keyLastMainHeartbeat, value);

  static bool get isBackgroundSyncActive => _prefs?.getBool(keyBackgroundSyncActive) ?? false;
  static set isBackgroundSyncActive(bool value) => _prefs?.setBool(keyBackgroundSyncActive, value);

  static int get lastTotal => _prefs?.getInt(keyLastTotal) ?? 0;
  static set lastTotal(int value) => _prefs?.setInt(keyLastTotal, value);

  static int get lastSyncedCount => _prefs?.getInt(keyLastSyncedCount) ?? 0;
  static set lastSyncedCount(int value) => _prefs?.setInt(keyLastSyncedCount, value);

  static int get lastInQueue => _prefs?.getInt(keyLastInQueue) ?? 0;
  static set lastInQueue(int value) => _prefs?.setInt(keyLastInQueue, value);

  static int get lastFailed => _prefs?.getInt(keyLastFailed) ?? 0;
  static set lastFailed(int value) => _prefs?.setInt(keyLastFailed, value);

  static int get lastUploading => _prefs?.getInt(keyLastUploading) ?? 0;
  static set lastUploading(int value) => _prefs?.setInt(keyLastUploading, value);

  static Future<void> clearSessionState() async {
    await _prefs?.remove(keySessionTotal);
    await _prefs?.remove(keySessionSynced);
    await _prefs?.remove(keySessionComplete);
    await _prefs?.remove(keySessionProgress);
    await _prefs?.remove(keyLastTotal);
    await _prefs?.remove(keyLastSyncedCount);
    await _prefs?.remove(keyLastInQueue);
    await _prefs?.remove(keyLastFailed);
    await _prefs?.remove(keyLastUploading);
  }

  static Future<void> clearAllSyncState() async {
    await _prefs?.remove(keyLastSynced);
    await _prefs?.remove(keyEnabled);
    await _prefs?.remove(keyUploadPaused);
    await clearSessionState();
  }
}
