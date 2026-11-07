import 'package:flutter/material.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

class DashboardControlDeck extends StatelessWidget {
  final bool isConfigured;
  final bool isMonitoring;
  final bool isPaused;
  final bool isScanning;
  final VoidCallback onTogglePause;
  final VoidCallback onScanGallery;
  final VoidCallback onStopProcess;
  final VoidCallback onShowDiagnostics;

  const DashboardControlDeck({
    super.key,
    required this.isConfigured,
    required this.isMonitoring,
    required this.isPaused,
    required this.isScanning,
    required this.onTogglePause,
    required this.onScanGallery,
    required this.onStopProcess,
    required this.onShowDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = ValtSkyTheme.textSecondary(isDark);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final spacing = isNarrow ? 8.0 : 12.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'QUICK CONTROLS',
                style: ValtSkyTheme.capsLabel(isDark: isDark, color: mutedText),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    title: isPaused ? 'Resume' : 'Pause',
                    icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    iconColor: isPaused ? ValtSkyTheme.amber : ValtSkyTheme.warning,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    isEnabled: isConfigured,
                    onTap: isConfigured ? onTogglePause : null,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildActionTile(
                    title: 'Scan Gallery',
                    icon: Icons.photo_camera_back_outlined,
                    iconColor: ValtSkyTheme.amber,
                    isDark: isDark,
                    isNarrow: isNarrow,
                    isLoading: isScanning,
                    onTap: isScanning ? null : onScanGallery,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    title: 'Stop Process',
                    icon: Icons.stop_circle_outlined,
                    iconColor: ValtSkyTheme.statusFailed, // Subtle coral icon
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: onStopProcess,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _buildActionTile(
                    title: 'Diagnostics',
                    icon: Icons.terminal_rounded,
                    iconColor: ValtSkyTheme.accentText(isDark),
                    isDark: isDark,
                    isNarrow: isNarrow,
                    onTap: onShowDiagnostics,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required bool isNarrow,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    final bg = ValtSkyTheme.surface(isDark);
    final borderColor = ValtSkyTheme.hairline(isDark);
    final opacity = isEnabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: TactilePress(
        onTap: onTap,
        scaleDown: 0.97,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56.0),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(ValtSkyTheme.radiusCard),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, size: 20, color: iconColor),
              ),
              SizedBox(width: isNarrow ? 10 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ValtSkyTheme.fontFamily,
                    fontSize: isNarrow ? 12.5 : 13.5,
                    fontWeight: FontWeight.w700,
                    color: ValtSkyTheme.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
