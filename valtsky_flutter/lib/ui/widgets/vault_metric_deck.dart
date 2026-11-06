import 'package:flutter/material.dart';
import '../../util/theme.dart';

class VaultMetricDeck extends StatelessWidget {
  final int totalCount;
  final int uploadedCount;
  final int pendingCount;
  final int failedCount;
  final void Function(String? filter) onNavigateToActivity;

  const VaultMetricDeck({
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
    final primaryColor = ValtSkyTheme.primary(isDark);
    final secondaryColor = ValtSkyTheme.secondary(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final spacing = isNarrow ? 8.0 : 12.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'TOTAL MEDIA',
                    value: '$totalCount',
                    icon: Icons.photo_library_outlined,
                    accentColor: primaryColor,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: () => onNavigateToActivity('ALL'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildMetricTile(
                    title: 'SYNCED',
                    value: '$uploadedCount',
                    icon: Icons.cloud_done_rounded,
                    accentColor: secondaryColor,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: () => onNavigateToActivity('DONE'),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'IN QUEUE',
                    value: '$pendingCount',
                    icon: Icons.hourglass_top_rounded,
                    accentColor: pendingCount > 0 ? ValtSkyTheme.warning : secondaryColor,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: () => onNavigateToActivity('PENDING'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildMetricTile(
                    title: 'FAILED',
                    value: '$failedCount',
                    icon: Icons.error_outline_rounded,
                    accentColor: failedCount > 0 ? ValtSkyTheme.error : mutedText,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    hasAlert: failedCount > 0,
                    onTap: () => onNavigateToActivity('FAILED'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required bool isNarrow,
    required VoidCallback onTap,
    bool hasAlert = false,
  }) {
    final bg = ValtSkyTheme.tertiaryCard(isDark);
    final borderColor = hasAlert
        ? ValtSkyTheme.error.withAlpha(140)
        : ValtSkyTheme.tertiaryBorder(isDark);
    final mutedText = ValtSkyTheme.tertiaryText(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: isNarrow ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: hasAlert ? 1.5 : 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 28 : 6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isNarrow ? 34 : 38,
                height: isNarrow ? 34 : 38,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: isNarrow ? 18 : 20, color: accentColor),
              ),
              SizedBox(width: isNarrow ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isNarrow ? 9.5 : 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: isNarrow ? 17 : 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
