import 'package:flutter/material.dart';
import '../../util/theme.dart';
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

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bento Left: Tall Tile for TOTAL MEDIA (biggest numeral)
              Expanded(
                flex: 5,
                child: StatTile(
                  label: 'TOTAL MEDIA',
                  value: totalCount,
                  icon: Icons.photo_library_outlined,
                  isTall: true,
                  onTap: () => onNavigateToActivity('ALL'),
                ),
              ),

              SizedBox(width: spacing),

              // Bento Right: Stacked Tiles for SYNCED, IN QUEUE, FAILED
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    StatTile(
                      label: 'SYNCED',
                      value: uploadedCount,
                      icon: Icons.cloud_done_rounded,
                      accentColor: uploadedCount > 0 ? ValtSkyTheme.statusSynced : null,
                      onTap: () => onNavigateToActivity('DONE'),
                    ),
                    SizedBox(height: spacing),
                    StatTile(
                      label: 'IN QUEUE',
                      value: pendingCount,
                      icon: Icons.hourglass_top_rounded,
                      onTap: () => onNavigateToActivity('PENDING'),
                    ),
                    SizedBox(height: spacing),
                    StatTile(
                      label: 'FAILED',
                      value: failedCount,
                      icon: Icons.error_outline_rounded,
                      accentColor: failedCount > 0 ? ValtSkyTheme.statusFailed : null,
                      hasAlert: failedCount > 0,
                      onTap: () => onNavigateToActivity('FAILED'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
