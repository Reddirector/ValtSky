import 'package:flutter/material.dart';
import '../../util/formatters.dart';
import '../../util/theme.dart';

class DashboardStatsGrid extends StatelessWidget {
  final int totalCount;
  final int uploadedCount;
  final int pendingCount;
  final int failedCount;
  final void Function(String? filter) onNavigateToActivity;

  const DashboardStatsGrid({
    super.key,
    required this.totalCount,
    required this.uploadedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.onNavigateToActivity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'TOTAL MEDIA',
                value: ValtSkyFormatters.formatMediaCount(totalCount),
                icon: Icons.photo_library_outlined,
                accentColor: isDark ? Colors.white : Colors.black87,
                isDark: isDark,
                onTap: () => onNavigateToActivity('ALL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'SYNCED',
                value: ValtSkyFormatters.formatMediaCount(uploadedCount),
                icon: Icons.cloud_done_rounded,
                accentColor: ValtSkyTheme.success,
                isDark: isDark,
                onTap: () => onNavigateToActivity('DONE'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'IN QUEUE',
                value: ValtSkyFormatters.formatMediaCount(pendingCount),
                icon: Icons.hourglass_top_rounded,
                accentColor: ValtSkyTheme.warning,
                isDark: isDark,
                onTap: () => onNavigateToActivity('PENDING'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'FAILED',
                value: ValtSkyFormatters.formatMediaCount(failedCount),
                icon: Icons.error_outline_rounded,
                accentColor: failedCount > 0 ? ValtSkyTheme.error : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                isDark: isDark,
                hasAlert: failedCount > 0,
                onTap: () => onNavigateToActivity('FAILED'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
    bool hasAlert = false,
  }) {
    final bg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = hasAlert
        ? ValtSkyTheme.error.withAlpha(120)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accentColor.withAlpha(20),
        highlightColor: accentColor.withAlpha(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: hasAlert ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: hasAlert ? ValtSkyTheme.error.withAlpha(25) : Colors.black.withAlpha(isDark ? 30 : 8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
