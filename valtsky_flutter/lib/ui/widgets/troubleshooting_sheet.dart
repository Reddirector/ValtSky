import 'package:flutter/material.dart';
import '../../data/prefs.dart';
import '../../util/theme.dart';
import 'health_status_banner.dart';

class TroubleshootingSheet extends StatelessWidget {
  final List<SystemIssue> issues;
  final VoidCallback onDataChanged;

  const TroubleshootingSheet({
    super.key,
    required this.issues,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasIssues = issues.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121214) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasIssues ? ValtSkyTheme.error : ValtSkyTheme.success).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasIssues ? Icons.medical_services_rounded : Icons.verified_user_rounded,
                  color: hasIssues ? ValtSkyTheme.error : ValtSkyTheme.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasIssues ? 'System Health & Troubleshooting' : 'System Fully Operational',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      hasIssues
                          ? 'Resolve the items below for smooth automatic backups'
                          : 'All credentials, rules, and network checks passed',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Issues list
          if (hasIssues) ...[
            ...issues.map((issue) => _buildIssueCard(context, issue, isDark)),
          ] else ...[
            _buildAllHealthyCard(isDark),
          ],

          const SizedBox(height: 20),

          // Diagnostic checklist summary
          _buildDiagnosticsChecklist(isDark),
        ],
      ),
    );
  }

  Widget _buildIssueCard(BuildContext context, SystemIssue issue, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: issue.color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: issue.color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(issue.icon, color: issue.color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  issue.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: issue.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      issue.onFix();
                    },
                    child: Text(
                      issue.actionLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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

  Widget _buildAllHealthyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ValtSkyTheme.success.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ValtSkyTheme.success.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.thumb_up_rounded, color: ValtSkyTheme.success, size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Issues Detected',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 2),
                Text(
                  'Your Telegram bot is verified and standing by to sync new photos and videos automatically.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsChecklist(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1520) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF243046) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIAGNOSTIC STATUS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Bot API Token',
            Prefs.botToken.isNotEmpty,
            Prefs.botToken.isNotEmpty ? 'Token loaded' : 'Missing token',
          ),
          _buildCheckItem(
            'Target Channel',
            Prefs.channelId.isNotEmpty,
            Prefs.channelId.isNotEmpty ? Prefs.channelName.ifEmpty('Connected') : 'Channel not set',
          ),
          _buildCheckItem(
            'Bit-for-Bit Lossless Mode',
            Prefs.useOriginalQuality,
            Prefs.useOriginalQuality ? 'Active (zero loss)' : 'Lossy compression',
          ),
          _buildCheckItem(
            'Smart Multi-Part Chunking',
            Prefs.enableChunking,
            Prefs.enableChunking ? 'Active (Any size supported)' : 'Disabled (>50MB will fail)',
          ),
          _buildCheckItem(
            'Network Policy',
            true,
            Prefs.uploadNetworkType == NetworkTypeChoice.both
                ? 'Wi-Fi & Mobile Allowed'
                : (Prefs.uploadNetworkType == NetworkTypeChoice.wifi ? 'Wi-Fi Only' : 'Mobile Only'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isOk, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 14,
                color: isOk ? ValtSkyTheme.success : ValtSkyTheme.error,
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOk ? Colors.grey : ValtSkyTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
