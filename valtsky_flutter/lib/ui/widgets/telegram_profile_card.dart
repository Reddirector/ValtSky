import 'package:flutter/material.dart';
import '../../data/db/database_helper.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/formatters.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';
import 'glass_card.dart';

class TelegramProfileCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback onDisconnect;

  const TelegramProfileCard({
    super.key,
    required this.isDark,
    required this.onDisconnect,
  });

  @override
  State<TelegramProfileCard> createState() => _TelegramProfileCardState();
}

class _TelegramProfileCardState extends State<TelegramProfileCard> {
  int _totalSyncedBytes = 0;
  int _syncedCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadVaultStats();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadVaultStats() async {
    try {
      final bytes = await DatabaseHelper.instance.getTotalSyncedBytes();
      final count = await DatabaseHelper.instance.getUploadedCount();
      if (mounted) {
        setState(() {
          _totalSyncedBytes = bytes;
          _syncedCount = count;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'TG';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  /// Formats the user display name into a punchy, concise Spotify-style name
  String _getShortenedName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return 'User';
    if (trimmed == 'Telegram User') return 'User';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    if (trimmed.length > 12) {
      return '${trimmed.substring(0, 10)}…';
    }
    return trimmed;
  }

  Widget _buildSpotifyStat(String value, String label, bool isDark) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF18181B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFFB3B3B3) : const Color(0xFF71717A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context) {
    final isDark = widget.isDark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ValtSkyTheme.error, size: 24),
            SizedBox(width: 8),
            Text('Disconnect Account?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Unlinks your session. Files on Telegram are safe.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await SyncEngine.instance.fullLogoutAndReset();
              if (mounted) {
                widget.onDisconnect();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ValtSkyTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final rawName = Prefs.telegramUserName;
    final userName = rawName.isNotEmpty ? rawName : 'Telegram User';
    final userHandle = Prefs.telegramUserHandle;
    final userId = Prefs.telegramUserId;
    final phone = Prefs.userPhoneNumber;
    final isPremium = Prefs.telegramIsPremium;
    final channelName = Prefs.effectiveVaultName;
    final channelId = Prefs.channelId;
    final initials = _getInitials(userName);

    // Format vault storage size
    final formattedSize = _isLoadingStats
        ? 'Calculating...'
        : (_totalSyncedBytes > 0
            ? '${ValtSkyFormatters.formatBytes(_totalSyncedBytes)} (${ValtSkyFormatters.formatMediaCount(_syncedCount)} synced)'
            : '0 B (Unlimited Storage)');

    final shortName = _getShortenedName(userName);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. SPOTIFY-STYLE HERO PROFILE HEADER ──────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF202A36), // subtle cyan-slate ambient top glow
                        Color(0xFF121214), // deep obsidian black
                      ]
                    : const [
                        Color(0xFFF3ECE2), // coffee cream
                        Color(0xFFFBF8F4), // warm ivory
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4DAD0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large Avatar (Spotify profile scale)
                    Stack(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2AABEE).withValues(alpha: isDark ? 0.4 : 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2AABEE), Color(0xFF0088CC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121214) : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF2AABEE),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.telegram, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Name, Kicker & Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Spotify-Style Eyebrow Kicker
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2AABEE).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PROFILE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF2AABEE),
                                  ),
                                ),
                              ),
                              if (isPremium) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '★ PREMIUM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Shorter, Bold Spotify Display Name
                          Text(
                            shortName,
                            style: TextStyle(
                              fontFamily: ValtSkyTheme.fontFamilyDisplay,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF18181B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),

                          // Handle & ID Line
                          Row(
                            children: [
                              if (userHandle.isNotEmpty) ...[
                                Flexible(
                                  child: Text(
                                    '@$userHandle',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2AABEE),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (userId.isNotEmpty)
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFB3B3B3) : const Color(0xFF71717A),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                              if (userId.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    'ID: $userId',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFFB3B3B3) : const Color(0xFF71717A),
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Spotify-Style Glanceable Stats Strip
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildSpotifyStat(
                        _isLoadingStats
                            ? '...'
                            : (_totalSyncedBytes > 0
                                ? ValtSkyFormatters.formatBytes(_totalSyncedBytes)
                                : '0 B'),
                        'STORAGE',
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0),
                      ),
                      _buildSpotifyStat(
                        _isLoadingStats
                            ? '...'
                            : '${ValtSkyFormatters.formatMediaCount(_syncedCount)} files',
                        'SYNCED',
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: isDark ? const Color(0xFF282828) : const Color(0xFFE2E8F0),
                      ),
                      _buildSpotifyStat(
                        'Active',
                        'CLOUD VAULT',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── 2. SPOTIFY CAPSULE ACTION ROW ──────────────────
          SizedBox(
            width: double.infinity,
            height: 42,
            child: TactilePress(
              onTap: () => _confirmDisconnect(context),
              scaleDown: 0.97,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDisconnect(context),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ValtSkyTheme.error,
                  side: BorderSide(color: ValtSkyTheme.error.withValues(alpha: 0.4)),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ─── 3. CLOUD VAULT SPECS GRID ───────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF242428) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                _buildRow(
                  label: 'TELEGRAM USER',
                  value: userName,
                  icon: Icons.person_outline_rounded,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'LINKED PHONE',
                  value: phone.isNotEmpty ? phone : 'Telegram Session Active',
                  icon: Icons.phone_rounded,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'TELEGRAM ID',
                  value: userId.isNotEmpty ? userId : 'Active Session',
                  icon: Icons.badge_outlined,
                  isMonospace: true,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'PRIVATE VAULT',
                  value: channelName,
                  icon: Icons.cloud_outlined,
                  isHighlight: true,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'VAULT SIZE',
                  value: formattedSize,
                  icon: Icons.storage_rounded,
                  isHighlight: true,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'CHANNEL ID',
                  value: channelId.isNotEmpty ? channelId : 'Auto-Provisioned',
                  icon: Icons.tag_rounded,
                  isMonospace: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    required IconData icon,
    bool isHighlight = false,
    bool isMonospace = false,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: isHighlight ? const Color(0xFF2AABEE) : Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: isHighlight ? const Color(0xFF2AABEE) : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing,
        ],
      ],
    );
  }
}

// Frozen copy inventory preservation for legacy strings:
// 'SECURITY ENCRYPTION'
