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
import '../widgets/animated_stagger.dart';
import '../widgets/valtsky_logo.dart';
import '../widgets/valtsky_components.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
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

          // ─── PERFORMANCE & ZERO-LAG ENGINE ────────────────
          StaggeredFadeSlide(
            delayMs: 60,
            child: _buildPerformanceCard(isDark),
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

    return Container(
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.telegram, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Telegram Bot API',
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamilyDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ValtSkyTheme.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
              if (isConfigured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.synced(isDark).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: ValtSkyTheme.synced(isDark)),
                      const SizedBox(width: 4),
                      Text(
                        'CONNECTED',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.synced(isDark),
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
                style: TextStyle(
                  fontFamily: ValtSkyTheme.fontFamilyBody,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ValtSkyTheme.accentText(isDark),
                ),
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
          PillButton(
            label: _isValidating ? 'VALIDATING...' : 'VALIDATE & SAVE',
            icon: Icons.check_circle_outline_rounded,
            isLoading: _isValidating,
            onPressed: _isValidating ? null : _handleValidate,
          ),

          if (!isConfigured) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _authMode = 'phone'),
                icon: Icon(Icons.phone_android_rounded, size: 16, color: ValtSkyTheme.accentText(isDark)),
                label: Text(
                  'Switch to Direct Phone Login',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 12,
                    color: ValtSkyTheme.accentText(isDark),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZeroLossEngineCard(bool isDark) {
    return Container(
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.all_inclusive_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Any-Size Lossless Engine',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ValtSkyTheme.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero compression mode',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 11,
                        color: ValtSkyTheme.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Lossless Document Mode
          MorphingToggleRow(
            title: '100% Bit-for-Bit Lossless Mode',
            subtitle: 'Preserves exact camera bytes & EXIF.',
            value: _useOriginalQuality,
            onChanged: (val) {
              setState(() => _useOriginalQuality = val);
              Prefs.useOriginalQuality = val;
            },
          ),
          Divider(height: 20, color: ValtSkyTheme.hairline(isDark)),

          // Smart Multi-Part Chunking
          MorphingToggleRow(
            title: 'Smart Multi-Part Chunking (Files > 50MB)',
            subtitle: 'Splits files into 48MB parts.',
            value: _enableChunking,
            onChanged: (val) {
              setState(() => _enableChunking = val);
              Prefs.enableChunking = val;
            },
          ),
          Divider(height: 20, color: ValtSkyTheme.hairline(isDark)),

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
              child: Text(
                'RESET',
                style: TextStyle(
                  fontFamily: ValtSkyTheme.fontFamilyBody,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ValtSkyTheme.accentText(isDark),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ValtSkyTheme.surface(isDark, level: 2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ValtSkyTheme.hairline(isDark),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 16, color: ValtSkyTheme.textPrimary(isDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Custom endpoint for direct 2GB uploads.',
                    style: TextStyle(
                      fontFamily: ValtSkyTheme.fontFamilyBody,
                      fontSize: 11,
                      color: ValtSkyTheme.textSecondary(isDark),
                    ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title,
          style: ValtSkyTheme.capsLabel(isDark: isDark),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            subtitle,
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 11,
              color: ValtSkyTheme.textSecondary(isDark),
            ),
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
        color: enabled ? ValtSkyTheme.surface(isDark) : ValtSkyTheme.raised(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ValtSkyTheme.hairline(isDark),
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
                fontFamily: ValtSkyTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? ValtSkyTheme.textPrimary(isDark) : ValtSkyTheme.textSecondary(isDark),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: ValtSkyTheme.fontFamily,
                  fontSize: 13,
                  color: ValtSkyTheme.textSecondary(isDark),
                ),
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: Prefs.smoothUploadModeNotifier,
      builder: (context, isSmooth, _) {
        return Container(
          decoration: ValtSkyTheme.cardDecoration(
            isDark: isDark,
            surfaceLevel: 1,
            radius: ValtSkyTheme.radiusCard,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.speed_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance & Battery',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyDisplay,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: ValtSkyTheme.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zero-lag upload engine',
                          style: TextStyle(
                            fontFamily: ValtSkyTheme.fontFamilyBody,
                            fontSize: 11,
                            color: ValtSkyTheme.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSmooth
                          ? ValtSkyTheme.synced(isDark).withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSmooth ? '120 FPS' : 'TURBO',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSmooth ? ValtSkyTheme.synced(isDark) : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Eco / Smooth Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isSmooth
                        ? '120 FPS silky-smooth UI & cooler device. Balanced concurrency (4 video / 2 photo parts).'
                        : 'Turbo Mode: Maximum wire speed with 8 video / 6 photo parts. Uses more CPU & battery.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isSmooth,
                  activeThumbColor: ValtSkyTheme.synced(isDark),
                  onChanged: (val) {
                    Prefs.smoothUploadMode = val;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? 'Eco / Smooth Mode enabled: UI locked at silky-smooth 120 FPS.'
                              : 'Turbo Mode enabled: Maximum parallel wire throughput.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncPreferencesCard(bool isDark, bool isMonitoring) {
    return Container(
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.wifi_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Network & Security Rules',
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyDisplay,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Network Type Selector
          Text(
            'Upload Network Preference',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyBody,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ValtSkyTheme.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<NetworkTypeChoice>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 0)),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? ValtSkyTheme.darkCanvas : ValtSkyTheme.paper;
                }
                return ValtSkyTheme.textSecondary(isDark);
              }),
              side: WidgetStatePropertyAll(
                BorderSide(color: ValtSkyTheme.hairline(isDark), width: 1),
              ),
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
          Divider(height: 24, color: ValtSkyTheme.hairline(isDark)),

          // Config Lock
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lock Configuration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('Prevent edits while syncing.', style: TextStyle(fontSize: 12)),
              value: _configLocked,
              activeThumbColor: isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk,
              onChanged: (val) {
                setState(() => _configLocked = val);
                Prefs.configLocked = val;
              },
            ),
          ),
          Divider(height: 24, color: ValtSkyTheme.hairline(isDark)),

          // Vault Privacy Lock
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vault Privacy Lock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(
                _vaultPinEnabled ? 'PIN lock active for vault protection.' : 'Protect vault with secure PIN code.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _vaultPinEnabled,
              activeThumbColor: isDark ? ValtSkyTheme.paper : ValtSkyTheme.lightInk,
              onChanged: (val) => _handleVaultPinToggle(val, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(bool isDark) {
    return Container(
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.security_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Permissions',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ValtSkyTheme.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gallery, Notifications, Location & Battery',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 11,
                        color: ValtSkyTheme.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPermissionStatusTile('Gallery Access', 'Photos, videos, and media library', Icons.photo_library_rounded, isDark),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Notifications', 'Live upload speed & sync status alerts', Icons.notifications_active_rounded, isDark),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Location & EXIF', 'Camera GPS tags preservation', Icons.location_on_rounded, isDark),
          const SizedBox(height: 8),
          _buildPermissionStatusTile('Battery Exemption', 'Uninterrupted background syncing', Icons.bolt_rounded, isDark),
          const SizedBox(height: 16),
          PillButton(
            label: 'MANAGE & GRANT PERMISSIONS',
            icon: Icons.refresh_rounded,
            onPressed: () => PermissionManager.showPermissionOnboardingModal(
              context,
              onComplete: () {
                widget.onDataChanged();
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusTile(String title, String desc, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ValtSkyTheme.surface(isDark, level: 2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamilyBody,
                    fontSize: 10.5,
                    color: ValtSkyTheme.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: ValtSkyTheme.synced(isDark)),
              const SizedBox(width: 4),
              Text(
                'Granted',
                style: TextStyle(
                  fontFamily: ValtSkyTheme.fontFamilyBody,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ValtSkyTheme.synced(isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetupGuide(bool isDark) {
    return Container(
      decoration: ValtSkyTheme.cardDecoration(
        isDark: isDark,
        surfaceLevel: 1,
        radius: ValtSkyTheme.radiusCard,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? ValtSkyTheme.darkSurface3 : ValtSkyTheme.lightInk,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.help_outline_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Setup Guide',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ValtSkyTheme.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Short steps to link your cloud vault',
                      style: TextStyle(
                        fontFamily: ValtSkyTheme.fontFamilyBody,
                        fontSize: 11,
                        color: ValtSkyTheme.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Method A: Phone Login
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ValtSkyTheme.surface(isDark, level: 2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android_rounded, size: 16, color: ValtSkyTheme.accentText(isDark)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Option 1: Phone Login (Fastest)',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGuideBullet('1', 'Enter phone number with country code (+91...).', isDark),
                _buildGuideBullet('2', 'Submit 5-digit login code from Telegram.', isDark),
                _buildGuideBullet('3', 'Connected! Private vault channel is ready.', isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Method B: Bot Token
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ValtSkyTheme.surface(isDark, level: 2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ValtSkyTheme.hairline(isDark), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 16, color: ValtSkyTheme.accentText(isDark)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Option 2: Bot & Channel (Advanced)',
                        style: TextStyle(
                          fontFamily: ValtSkyTheme.fontFamilyBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ValtSkyTheme.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGuideBullet('1', 'Message @BotFather on Telegram for Bot Token.', isDark),
                _buildGuideBullet('2', 'Create private channel and add bot as Admin.', isDark),
                _buildGuideBullet('3', 'Forward any message to @userinfobot for Channel ID.', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Open Full Interactive App Guide CTA
          PillButton(
            label: 'OPEN FULL APP GUIDE',
            icon: Icons.menu_book_rounded,
            variant: PillButtonVariant.secondary,
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
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBullet(String step, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$step. ',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamilyBody,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ValtSkyTheme.textPrimary(isDark),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: ValtSkyTheme.fontFamilyBody,
                fontSize: 12,
                color: ValtSkyTheme.textSecondary(isDark),
                height: 1.35,
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
        color: ValtSkyTheme.statusFailed.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
        border: Border.all(
          color: ValtSkyTheme.statusFailed.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: ValtSkyTheme.statusFailed),
              SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontFamily: ValtSkyTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ValtSkyTheme.statusFailed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Wipes local sync index.',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 12,
              color: ValtSkyTheme.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleReset,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('RESET ALL SYNC HISTORY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ValtSkyTheme.statusFailed,
                  side: const BorderSide(color: ValtSkyTheme.statusFailed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ValtSkyTheme.radiusPill)),
                ),
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
              color: ValtSkyTheme.raised(isDark),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: ValtSkyTheme.hairline(isDark),
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
          Text(
            'ValtSky Multiplatform v2.0',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: ValtSkyTheme.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zero-Loss Telegram Cloud Storage • Open Source',
            style: TextStyle(
              fontFamily: ValtSkyTheme.fontFamily,
              fontSize: 11,
              color: ValtSkyTheme.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }
}
