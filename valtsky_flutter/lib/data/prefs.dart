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
  static const String keyChannelAccessHash = 'channel_access_hash';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
  }

  static String get botToken => _prefs?.getString(keyBotToken) ?? '';
  static set botToken(String value) => _prefs?.setString(keyBotToken, value.trim());

  static String get channelId => _prefs?.getString(keyChannelId) ?? '';
  static set channelId(String value) => _prefs?.setString(keyChannelId, value.trim());

  static bool get monitoringEnabled => _prefs?.getBool(keyEnabled) ?? false;
  static set monitoringEnabled(bool value) => _prefs?.setBool(keyEnabled, value);

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

  static Future<void> clearAllSyncState() async {
    await _prefs?.remove(keyLastSynced);
    await _prefs?.remove(keyEnabled);
    await _prefs?.remove(keyUploadPaused);
  }
}
