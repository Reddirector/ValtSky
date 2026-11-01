import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../util/theme.dart';
import 'troubleshooting_sheet.dart';

class SystemIssue {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback onFix;

  SystemIssue({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onFix,
  });
}

class HealthStatusBanner extends StatelessWidget {
  final int failedCount;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToActivity;
  final VoidCallback onDataChanged;

  const HealthStatusBanner({
    super.key,
    required this.failedCount,
    required this.onNavigateToSettings,
    required this.onNavigateToActivity,
    required this.onDataChanged,
  });

  List<SystemIssue> _detectIssues(BuildContext context) {
    final issues = <SystemIssue>[];

    // 1. Missing Bot Token
    if (Prefs.botToken.isEmpty) {
      issues.add(SystemIssue(
        title: 'Telegram Bot Token Missing',
        description: 'No bot token configured. Create one with @BotFather to enable backups.',
        icon: Icons.key_off_rounded,
        color: ValtSkyTheme.error,
        actionLabel: 'Add Token',
        onFix: onNavigateToSettings,
      ));
    }

    // 2. Missing Channel ID
    if (Prefs.channelId.isEmpty) {
      issues.add(SystemIssue(
        title: 'Telegram Channel Not Connected',
        description: 'No target channel ID found. Add your bot as Admin in your private channel.',
        icon: Icons.cell_tower_rounded,
        color: ValtSkyTheme.error,
        actionLabel: 'Connect Channel',
        onFix: onNavigateToSettings,
      ));
    }

    // 3. Network Restriction Warning
    if (Prefs.uploadNetworkType == NetworkTypeChoice.wifi) {
      issues.add(SystemIssue(
        title: 'Wi-Fi Only Mode Active',
        description: 'Uploads will halt whenever disconnected from Wi-Fi.',
        icon: Icons.wifi_lock_rounded,
        color: ValtSkyTheme.warning,
        actionLabel: 'Allow Mobile',
        onFix: () {
          Prefs.uploadNetworkType = NetworkTypeChoice.both;
          onDataChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network preference updated to: Wi-Fi + Mobile Data')),
          );
        },
      ));
    }

    // 4. Failed Items in Queue
    if (failedCount > 0) {
      issues.add(SystemIssue(
        title: '$failedCount Upload${failedCount > 1 ? 's' : ''} Failed',
        description: 'Files in queue encountered an error (file size or rate limits).',
        icon: Icons.sync_problem_rounded,
        color: ValtSkyTheme.error,
        actionLabel: 'Inspect & Retry',
        onFix: onNavigateToActivity,
      ));
    }

    // 5. Upload Paused
    if (Prefs.uploadPaused && Prefs.monitoringEnabled) {
      issues.add(SystemIssue(
        title: 'Upload Queue Is Paused',
        description: 'New media is being detected, but uploads are temporarily paused.',
        icon: Icons.pause_circle_filled_rounded,
        color: ValtSkyTheme.warning,
        actionLabel: 'Resume Now',
        onFix: () {
          Prefs.uploadPaused = false;
          onDataChanged();
        },
      ));
    }

    return issues;
  }

  void _openTroubleshootingSheet(BuildContext context, List<SystemIssue> issues) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TroubleshootingSheet(
        issues: issues,
        onDataChanged: onDataChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issues = _detectIssues(context);
    final hasIssues = issues.isNotEmpty;

    final bannerColor = hasIssues
        ? (issues.any((e) => e.color == ValtSkyTheme.error) ? ValtSkyTheme.error : ValtSkyTheme.warning)
        : ValtSkyTheme.success;

    return InkWell(
      onTap: () => _openTroubleshootingSheet(context, issues),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bannerColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasIssues ? Icons.healing_rounded : Icons.check_circle_rounded,
                color: bannerColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        hasIssues 
                            ? '${issues.length} Issue${issues.length > 1 ? 's' : ''} Require Attention' 
                            : 'All Systems Operational',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (hasIssues)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bannerColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'FIX',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: bannerColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasIssues
                        ? issues.first.title
                        : 'Credentials verified, lossless engine ready, network open.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
