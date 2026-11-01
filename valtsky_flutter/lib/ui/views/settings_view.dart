import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../data/db/database_helper.dart';
import '../../services/telegram_api.dart';
import '../../util/theme.dart';
import '../../util/file_security_guard.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_stagger.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback onDataChanged;

  const SettingsView({super.key, required this.onDataChanged});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _botTokenController = TextEditingController();
  final TextEditingController _channelIdController = TextEditingController();
  final TextEditingController _apiServerController = TextEditingController();

  bool _showToken = false;
  bool _isValidating = false;
  bool _configLocked = Prefs.configLocked;
  bool _useOriginalQuality = Prefs.useOriginalQuality;
  bool _enableChunking = Prefs.enableChunking;
  NetworkTypeChoice _networkType = Prefs.uploadNetworkType;

  @override
  void initState() {
    super.initState();
    _botTokenController.text = Prefs.botToken;
    _channelIdController.text = Prefs.channelId;
    _apiServerController.text = Prefs.apiBaseUrl;
  }

  Future<void> _handleValidate() async {
    final token = _botTokenController.text.trim();
    final channel = _channelIdController.text.trim();
    final customUrl = _apiServerController.text.trim();

    if (token.isEmpty || channel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Please enter both Bot Token and Channel ID'),
        ),
      );
      return;
    }

    if (customUrl.isNotEmpty) {
      final urlValidation = FileSecurityGuard.validateApiUrl(customUrl);
      if (!urlValidation.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('🛡️ Security Warning: ${urlValidation.error}'),
          ),
        );
        return;
      }
      Prefs.apiBaseUrl = customUrl;
    }

    setState(() => _isValidating = true);

    try {
      final botName = await TelegramApi.getBotInfo(token);
      if (botName != null) {
        final channelName = await TelegramApi.getChannelInfo(token, channel);
        if (channelName != null) {
          Prefs.botToken = token;
          Prefs.channelId = channel;
          Prefs.botName = botName;
          Prefs.channelName = channelName;
          widget.onDataChanged();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: ValtSkyTheme.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Verified: @$botName in $channelName'),
                  ],
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: ValtSkyTheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: const Text('Channel not found or Bot is not an Administrator'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: ValtSkyTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text('Invalid Bot Token — could not authenticate with Telegram API'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _handleReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ValtSkyTheme.error),
            SizedBox(width: 10),
            Text('Deep Reset?'),
          ],
        ),
        content: const Text(
          'This will wipe all local sync history and re-upload your media from the beginning on the next sync run.\n\nFiles already in Telegram will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM RESET'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteAll();
      await Prefs.clearAllSyncState();
      widget.onDataChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text('Sync history wiped. Ready for fresh backup.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMonitoring = Prefs.monitoringEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── TELEGRAM CONFIG CARD ────────────────────────
          StaggeredFadeSlide(
            delayMs: 0,
            child: _buildTelegramConfigCard(isDark, isMonitoring),
          ),
          const SizedBox(height: 20),

          // ─── UNLIMITED SIZE & ZERO-LOSS ENGINE ───────────
          StaggeredFadeSlide(
            delayMs: 40,
            child: _buildZeroLossEngineCard(isDark),
          ),
          const SizedBox(height: 20),

          // ─── SYNC & NETWORK RULES ─────────────────────────
          StaggeredFadeSlide(
            delayMs: 80,
            child: _buildSyncPreferencesCard(isDark, isMonitoring),
          ),
          const SizedBox(height: 20),

          // ─── SETUP GUIDE (ACCORDION) ──────────────────────
          StaggeredFadeSlide(
            delayMs: 120,
            child: _buildSetupGuide(isDark),
          ),
          const SizedBox(height: 20),

          // ─── DANGER ZONE ──────────────────────────────────
          StaggeredFadeSlide(
            delayMs: 160,
            child: _buildDangerZone(isDark),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildTelegramConfigCard(bool isDark, bool isMonitoring) {
    final isConfigured = Prefs.isConfigured();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.telegram, size: 22, color: isDark ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  const Text(
                    'Telegram Bot API',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              if (isConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: ValtSkyTheme.success),
                      SizedBox(width: 4),
                      Text(
                        'CONNECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Bot Token field
          _buildFieldHeader('BOT TOKEN', 'Created via @BotFather'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _botTokenController,
            hint: '7123456789:AAFabcDEF123456...',
            isPassword: !_showToken,
            enabled: !_configLocked && !isMonitoring,
            suffix: TextButton(
              onPressed: () => setState(() => _showToken = !_showToken),
              child: Text(
                _showToken ? 'HIDE' : 'SHOW',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Channel ID field
          _buildFieldHeader('CHANNEL ID', 'Starts with -100 (e.g. -100123456789)'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _channelIdController,
            hint: '-100123456789',
            enabled: !_configLocked && !isMonitoring,
          ),
          const SizedBox(height: 16),

          // Validate Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isValidating ? null : _handleValidate,
              icon: _isValidating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _isValidating ? 'VALIDATING WITH TELEGRAM...' : 'VALIDATE & SAVE CREDENTIALS',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZeroLossEngineCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.all_inclusive_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Any-Size Lossless Engine',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Zero compression, full EXIF metadata, any duration',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Lossless Document Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('100% Bit-for-Bit Lossless Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: const Text('Transmits as raw Document. Preserves exact camera bytes, color profiles, and full EXIF.', style: TextStyle(fontSize: 12)),
            value: _useOriginalQuality,
            activeThumbColor: ValtSkyTheme.success,
            onChanged: (val) {
              setState(() => _useOriginalQuality = val);
              Prefs.useOriginalQuality = val;
            },
          ),
          const Divider(height: 20),

          // Smart Multi-Part Chunking
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smart Multi-Part Chunking (Files > 50MB)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: const Text('Splits files >50MB into 48MB verified parts to bypass standard Bot API limits.', style: TextStyle(fontSize: 12)),
            value: _enableChunking,
            activeThumbColor: ValtSkyTheme.primaryAccent,
            onChanged: (val) {
              setState(() => _enableChunking = val);
              Prefs.enableChunking = val;
            },
          ),
          const Divider(height: 20),

          // Custom API Server URL
          _buildFieldHeader('TELEGRAM API SERVER', 'Default: https://api.telegram.org'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _apiServerController,
            hint: 'https://api.telegram.org',
            suffix: TextButton(
              onPressed: () {
                _apiServerController.text = 'https://api.telegram.org';
                Prefs.apiBaseUrl = 'https://api.telegram.org';
                setState(() {});
              },
              child: const Text('RESET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Bot API: Enter custom endpoint to unlock single-file 2 GB uploads without chunking.',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool enabled = true,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? (enabled ? const Color(0xFF18181B) : const Color(0xFF121214))
            : (enabled ? const Color(0xFFFAFAFA) : const Color(0xFFF4F4F5)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              enabled: enabled,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _buildSyncPreferencesCard(bool isDark, bool isMonitoring) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              const Text(
                'Network & Security Rules',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Network Type Selector
          const Text('Upload Network Preference', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<NetworkTypeChoice>(
            segments: const [
              ButtonSegment(value: NetworkTypeChoice.wifi, label: Text('Wi-Fi Only'), icon: Icon(Icons.wifi_rounded, size: 16)),
              ButtonSegment(value: NetworkTypeChoice.both, label: Text('Both'), icon: Icon(Icons.all_inclusive_rounded, size: 16)),
              ButtonSegment(value: NetworkTypeChoice.mobile, label: Text('Mobile'), icon: Icon(Icons.signal_cellular_alt_rounded, size: 16)),
            ],
            selected: {_networkType},
            onSelectionChanged: (val) {
              setState(() => _networkType = val.first);
              Prefs.uploadNetworkType = val.first;
            },
          ),
          const Divider(height: 24),

          // Config Lock
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lock Configuration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: const Text('Prevent accidental token or channel edits during sync', style: TextStyle(fontSize: 12)),
            value: _configLocked,
            activeThumbColor: ValtSkyTheme.primaryAccent,
            onChanged: (val) {
              setState(() => _configLocked = val);
              Prefs.configLocked = val;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSetupGuide(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              const Text(
                'Telegram Setup Guide',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGuideStep(
            stepNumber: '1',
            title: 'Create a Bot with @BotFather',
            description: 'Open Telegram, search for @BotFather (verified), send /newbot, name your bot, and copy the Bot Token.',
          ),
          _buildGuideStep(
            stepNumber: '2',
            title: 'Create a Private Channel',
            description: 'Create a new Telegram channel, set it to Private, add your bot as an Administrator with "Post Messages" permission.',
          ),
          _buildGuideStep(
            stepNumber: '3',
            title: 'Obtain Channel ID',
            description: 'Send any message in your channel, forward it to @userinfobot, and copy the ID (including the minus sign, e.g. -1001234567890).',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String stepNumber,
    required String title,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500], height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1315) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ValtSkyTheme.error.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: ValtSkyTheme.error),
              SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ValtSkyTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Resetting sync history will wipe all local indexes. Your media in Telegram is preserved, but ValtSky will re-upload from scratch.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _handleReset,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('RESET ALL SYNC HISTORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ValtSkyTheme.error,
                side: const BorderSide(color: ValtSkyTheme.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
