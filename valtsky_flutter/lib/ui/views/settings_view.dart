import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../data/db/database_helper.dart';
import '../../services/telegram_api.dart';
import '../../services/background_service.dart';
import '../../services/sync_engine.dart';
import '../../util/theme.dart';
import '../../util/file_security_guard.dart';
import '../../util/permission_manager.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_stagger.dart';
import '../widgets/valtsky_logo.dart';
import '../widgets/telegram_phone_login_widget.dart';
import '../widgets/telegram_profile_card.dart';
import '../widgets/app_walkthrough_guide.dart';

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
  bool _vaultPinEnabled = Prefs.vaultPinEnabled;
  NetworkTypeChoice _networkType = Prefs.uploadNetworkType;
  late String _authMode;

  @override
  void initState() {
    super.initState();
    _authMode = Prefs.authMethod;
    _vaultPinEnabled = Prefs.vaultPinEnabled;
    _botTokenController.text = Prefs.botToken;
    _channelIdController.text = Prefs.channelId;
    _apiServerController.text = Prefs.apiBaseUrl;
  }

  @override
  void dispose() {
    _botTokenController.dispose();
    _channelIdController.dispose();
    _apiServerController.dispose();
    super.dispose();
  }

  Future<void> _handleValidate() async {
    final token = _botTokenController.text.trim();
    var channel = _channelIdController.text.trim();
    final customUrl = _apiServerController.text.trim();

    // Smart auto-format channel ID: If user enters 9-13 pure digits without -100, auto-prepend -100
    if (RegExp(r'^\d{9,13}$').hasMatch(channel)) {
      channel = '-100$channel';
      _channelIdController.text = channel;
    }

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
          Prefs.monitoringEnabled = true;
          widget.onDataChanged();

          if (!kIsWeb) {
            try {
              await BackgroundService.start();
            } catch (e) {
              debugPrint('BackgroundService start error: $e');
            }
          }
          await SyncEngine.instance.initializeNewVaultSession();
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
          'Wipes local sync history. Files in Telegram will not be deleted.',
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

  Future<void> _handleVaultPinToggle(bool enable, bool isDark) async {
    if (enable) {
      final pinController = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ValtSkyTheme.tertiaryCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: ValtSkyTheme.primaryAccent, size: 22),
              SizedBox(width: 10),
              Text('Set Vault PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter a 4-digit security PIN to protect your cloud vault:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  filled: true,
                  fillColor: ValtSkyTheme.tertiaryTrack(isDark),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.primary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin.length == 4) {
                  Navigator.pop(ctx, pin);
                }
              },
              child: const Text('Set PIN'),
            ),
          ],
        ),
      );
      pinController.dispose();

      if (result != null && result.length == 4) {
        Prefs.vaultPin = result;
        Prefs.vaultPinEnabled = true;
        setState(() => _vaultPinEnabled = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Vault Privacy Lock enabled with 4-digit PIN')),
          );
        }
      }
    } else {
      final pinController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ValtSkyTheme.tertiaryCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm PIN to Unlock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Current 4-digit PIN',
              filled: true,
              fillColor: ValtSkyTheme.tertiaryTrack(isDark),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.primary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (Prefs.verifyVaultPin(pinController.text.trim())) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN!')),
                  );
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
      pinController.dispose();

      if (confirmed == true) {
        Prefs.vaultPinEnabled = false;
        Prefs.vaultPin = '';
        setState(() => _vaultPinEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vault Privacy Lock disabled')),
          );
        }
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
            child: _authMode == 'phone'
                ? (!Prefs.isConfigured()
                    ? TelegramPhoneLoginWidget(
                        onLoginSuccess: () async {
                          setState(() {});
                          widget.onDataChanged();
                          if (!kIsWeb) {
                            try {
                              await BackgroundService.start();
                            } catch (e) {
                              debugPrint('BackgroundService start error: $e');
                            }
                          }
                          await SyncEngine.instance.initializeNewVaultSession();
                          widget.onDataChanged();
                        },
                        onSwitchToBotMode: () {
                          setState(() => _authMode = 'bot');
                        },
                      )
                    : TelegramProfileCard(
                        isDark: isDark,
                        onDisconnect: () {
                          setState(() {
                            _authMode = 'phone';
                          });
                          widget.onDataChanged();
                        },
                      ))
                : _buildTelegramConfigCard(isDark, isMonitoring),
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

          // ─── DEVICE PERMISSIONS ────────────────────────────
          StaggeredFadeSlide(
            delayMs: 100,
            child: _buildPermissionsCard(isDark),
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
          const SizedBox(height: 24),

          // ─── BRANDING FOOTER ──────────────────────────────
          StaggeredFadeSlide(
            delayMs: 200,
            child: _buildBrandingFooter(isDark),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildTelegramConfigCard(bool isDark, bool isMonitoring) {
    final isConfigured = Prefs.isConfigured();
    final isPhoneAuth = Prefs.authMethod == 'phone' && Prefs.userPhoneNumber.isNotEmpty;

    if (isConfigured && isPhoneAuth) {
      return TelegramProfileCard(
        isDark: isDark,
        onDisconnect: () {
          setState(() {
            _authMode = 'phone';
          });
          widget.onDataChanged();
        },
      );
    }

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
          _buildFieldHeader('BOT TOKEN', 'From @BotFather'),
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
          _buildFieldHeader('CHANNEL ID', 'Starts with -100'),
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
                _isValidating ? 'VALIDATING...' : 'VALIDATE & SAVE',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ValtSkyTheme.primary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          if (!isConfigured) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _authMode = 'phone'),
                icon: const Icon(Icons.phone_android_rounded, size: 16),
                label: const Text('Switch to Direct Phone Login', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
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
                      'Zero compression mode',
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
            subtitle: const Text('Preserves exact camera bytes & EXIF.', style: TextStyle(fontSize: 12)),
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
            subtitle: const Text('Splits files into 48MB parts.', style: TextStyle(fontSize: 12)),
            value: _enableChunking,
            activeThumbColor: ValtSkyTheme.primaryAccent,
            onChanged: (val) {
              setState(() => _enableChunking = val);
              Prefs.enableChunking = val;
            },
          ),
          const Divider(height: 20),

          // Custom API Server URL
          _buildFieldHeader('API SERVER', 'Default: api.telegram.org'),
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
                    'Custom endpoint for direct 2GB uploads.',
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
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
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
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 0)),
            ),
            segments: const [
              ButtonSegment(
                value: NetworkTypeChoice.wifi,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Wi-Fi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                icon: Icon(Icons.wifi_rounded, size: 16),
                tooltip: 'Wi-Fi only',
              ),
              ButtonSegment(
                value: NetworkTypeChoice.both,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Both', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                icon: Icon(Icons.all_inclusive_rounded, size: 16),
                tooltip: 'Wi-Fi and Cellular',
              ),
              ButtonSegment(
                value: NetworkTypeChoice.mobile,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Data', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                icon: Icon(Icons.signal_cellular_alt_rounded, size: 16),
                tooltip: 'Cellular data only',
              ),
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
            subtitle: const Text('Prevent edits while syncing.', style: TextStyle(fontSize: 12)),
            value: _configLocked,
            activeThumbColor: ValtSkyTheme.primary(isDark),
            onChanged: (val) {
              setState(() => _configLocked = val);
              Prefs.configLocked = val;
            },
          ),
          const Divider(height: 24),

          // Vault Privacy Lock
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vault Privacy Lock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(
              _vaultPinEnabled ? 'PIN lock active for vault protection.' : 'Protect vault with secure PIN code.',
              style: const TextStyle(fontSize: 12),
            ),
            value: _vaultPinEnabled,
            activeThumbColor: ValtSkyTheme.primary(isDark),
            onChanged: (val) => _handleVaultPinToggle(val, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(bool isDark) {
    final primaryColor = ValtSkyTheme.primary(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);

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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.security_rounded, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Permissions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Gallery, Notifications, Location & Battery',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPermissionStatusTile('Gallery Access', 'Photos, videos, and media library', Icons.photo_library_rounded, isDark, trackBg, borderColor),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Notifications', 'Live upload speed & sync status alerts', Icons.notifications_active_rounded, isDark, trackBg, borderColor),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Location & EXIF', 'Camera GPS tags preservation', Icons.location_on_rounded, isDark, trackBg, borderColor),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Battery Exemption', 'Uninterrupted background syncing', Icons.bolt_rounded, isDark, trackBg, borderColor),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => PermissionManager.showPermissionOnboardingModal(
                context,
                onComplete: () {
                  widget.onDataChanged();
                  if (mounted) setState(() {});
                },
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'MANAGE & GRANT PERMISSIONS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusTile(String title, String desc, IconData icon, bool isDark, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ValtSkyTheme.primary(isDark)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(desc, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, size: 14, color: ValtSkyTheme.success),
        ],
      ),
    );
  }

  Widget _buildSetupGuide(bool isDark) {
    final primaryColor = ValtSkyTheme.primary(isDark);
    final borderColor = ValtSkyTheme.tertiaryBorder(isDark);
    final trackBg = ValtSkyTheme.tertiaryTrack(isDark);

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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.help_outline_rounded, size: 20, color: primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Setup Guide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Short steps to link your cloud vault',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Method A: Phone Login
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: trackBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Option 1: Phone Login (Fastest)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGuideBullet('1', 'Enter phone number with country code (+91...).', isDark),
                _buildGuideBullet('2', 'Submit 5-digit login code from Telegram.', isDark),
                _buildGuideBullet('3', 'Connected! Private vault channel is ready.', isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Method B: Bot Token
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: trackBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Option 2: Bot & Channel (Advanced)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildGuideBullet('1', 'Message @BotFather on Telegram for Bot Token.', isDark),
                _buildGuideBullet('2', 'Create private channel and add bot as Admin.', isDark),
                _buildGuideBullet('3', 'Forward any message to @userinfobot for Channel ID.', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Open Full Interactive App Guide CTA
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                AppWalkthroughGuide.showWalkthroughSheet(
                  context,
                  isConfigured: Prefs.isConfigured(),
                  totalCount: 0,
                  isMonitoring: Prefs.monitoringEnabled,
                  onNavigateToSettings: () {},
                  onScanGallery: () {},
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.4), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text(
                'OPEN FULL APP GUIDE',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBullet(String step, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$step. ', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
              ),
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
            'Wipes local sync index.',
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

  Widget _buildBrandingFooter(bool isDark) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const ValtSkyLogo(size: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'ValtSky Multiplatform v2.0',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
          const SizedBox(height: 4),
          Text(
            'Zero-Loss Telegram Cloud Storage • Open Source',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
        ],
      ),
    );
  }
}
