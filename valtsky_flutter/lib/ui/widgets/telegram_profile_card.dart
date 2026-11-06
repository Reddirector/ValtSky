import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../services/sync_engine.dart';
import '../../util/telegram_launcher.dart';
import '../../util/theme.dart';
import 'glass_card.dart';
import 'animated_stagger.dart';

class TelegramProfileCard extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDisconnect;

  const TelegramProfileCard({
    super.key,
    required this.isDark,
    required this.onDisconnect,
  });

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'TG';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  void _confirmDisconnect(BuildContext context) {
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
              onDisconnect();
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
    final rawName = Prefs.telegramUserName;
    final userName = rawName.isNotEmpty ? rawName : 'Telegram User';
    final userHandle = Prefs.telegramUserHandle;
    final userId = Prefs.telegramUserId;
    final phone = Prefs.userPhoneNumber;
    final isPremium = Prefs.telegramIsPremium;
    final channelName = Prefs.channelName.isNotEmpty ? Prefs.channelName : 'ValtSky Private Vault';
    final channelId = Prefs.channelId;
    final initials = _getInitials(userName);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. USER PROFILE HEADER ────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                // Telegram Gradient Avatar
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.telegram, size: 14, color: Color(0xFF2AABEE)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name, Handle & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (userHandle.isNotEmpty) ...[
                            Text(
                              '@$userHandle',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2AABEE),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                          if (userId.isNotEmpty)
                            Text(
                              'ID: $userId',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── 3. CLOUD VAULT SPECS GRID ───────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141416) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildRow(
                  label: 'LINKED PHONE',
                  value: phone.isNotEmpty ? phone : 'Telegram Session Active',
                  icon: Icons.phone_rounded,
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
                  label: 'CHANNEL ID',
                  value: channelId.isNotEmpty ? channelId : 'Auto-Provisioned',
                  icon: Icons.tag_rounded,
                  isMonospace: true,
                ),
                const Divider(height: 16),
                _buildRow(
                  label: 'SECURITY ENCRYPTION',
                  value: 'MTProto 2.0 (Diffie-Hellman 2048-bit)',
                  icon: Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ─── ACTIONS: OPEN VAULT & LOGOUT ──────────────
          Row(
            children: [
              Expanded(
                child: TactilePress(
                  onTap: () => TelegramLauncher.openChannel(context),
                  scaleDown: 0.96,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => TelegramLauncher.openChannel(context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'Open Vault',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ValtSkyTheme.primary(isDark),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TactilePress(
                  onTap: () => _confirmDisconnect(context),
                  scaleDown: 0.96,
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDisconnect(context),
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ValtSkyTheme.error,
                        side: BorderSide(color: ValtSkyTheme.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      ],
    );
  }
}
