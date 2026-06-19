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

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  static bool isConfigured() => botToken.isNotEmpty && channelId.isNotEmpty;

  static Future<void> clearAllSyncState() async {
    await _prefs?.remove(keyLastSynced);
    await _prefs?.remove(keyEnabled);
    await _prefs?.remove(keyUploadPaused);
  }
}
