import 'package:flutter/material.dart';
import '../../util/theme.dart';
import 'valtsky_components.dart';

/// 2x2 Bento Stat Cards:
/// Each = 40pt ink icon chip with white glyph, 36 Light Outfit numeral,
/// 16x2 dash divider, and small-caps label.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final spacing = isNarrow ? 8.0 : 12.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'TOTAL MEDIA',
                    value: totalCount,
                    icon: Icons.photo_library_rounded,
                    accentColor: totalCount > 0 ? ValtSkyTheme.accent(isDark) : null,
                    onTap: () => onNavigateToActivity('ALL'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: StatTile(
                    label: 'SYNCED',
                    value: uploadedCount,
                    icon: Icons.cloud_done_rounded,
                    accentColor: uploadedCount > 0 ? ValtSkyTheme.synced(isDark) : null,
                    onTap: () => onNavigateToActivity('DONE'),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'IN QUEUE',
                    value: pendingCount,
                    icon: Icons.hourglass_top_rounded,
                    accentColor: pendingCount > 0 ? ValtSkyTheme.warning : null,
                    onTap: () => onNavigateToActivity('PENDING'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: StatTile(
                    label: 'FAILED',
                    value: failedCount,
                    icon: Icons.error_outline_rounded,
                    accentColor: failedCount > 0 ? ValtSkyTheme.failed(isDark) : null,
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
}
