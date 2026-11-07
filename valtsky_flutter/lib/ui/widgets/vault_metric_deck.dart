import 'package:flutter/material.dart';
import 'valtsky_components.dart';

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
                    title: 'TOTAL MEDIA',
                    value: '$totalCount',
                    icon: Icons.photo_library_outlined,
                    onTap: () => onNavigateToActivity('ALL'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: StatTile(
                    title: 'SYNCED',
                    value: '$uploadedCount',
                    icon: Icons.cloud_done_rounded,
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
                    title: 'IN QUEUE',
                    value: '$pendingCount',
                    icon: Icons.hourglass_top_rounded,
                    onTap: () => onNavigateToActivity('PENDING'),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: StatTile(
                    title: 'FAILED',
                    value: '$failedCount',
                    icon: Icons.error_outline_rounded,
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
